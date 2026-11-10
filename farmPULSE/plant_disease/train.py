"""
train.py
========
Complete training loop with:
- Warm-up then full Fine-tuning
- Cosine LR Scheduler with Warm Restarts
- Mixed Precision (AMP) for speedup
- Early Stopping
- Grad-CAM for visual explanation
- Detailed reports

Usage:
    # Quick training (default):
    python train.py

    # Full customization:
    python train.py --arch efficientnet_b3 --epochs 30 --batch-size 32 --img-size 224
"""

import argparse
import json
import time
from pathlib import Path
from typing import Optional

import numpy as np
import torch
import torch.nn as nn
from torch.cuda.amp import GradScaler, autocast
from tqdm import tqdm
import matplotlib.pyplot as plt
import seaborn as sns

from dataset import create_dataloaders
from model import PlantDiseaseModel, SmoothCrossEntropy, save_checkpoint, export_onnx


# ─── Default Configuration ────────────────────────────────────────────────
DEFAULTS = dict(
    arch         = "efficientnet_b3",
    img_size     = 224,
    batch_size   = 16,
    epochs       = 10,
    warmup_epochs = 5,
    lr           = 3e-4,
    min_lr       = 1e-6,
    weight_decay = 1e-4,
    dropout      = 0.4,
    label_smooth = 0.1,
    patience     = 7,
    data_dir     = "data/split",
    output_dir   = "outputs",
    num_workers  = 2,
)


# ─── Training Step ────────────────────────────────────────────────────────

def train_one_epoch(
    model, loader, optimizer, criterion, scaler, device,
) -> dict:
    """Train for one epoch"""
    model.train()
    total_loss = 0.0
    correct    = 0
    total      = 0

    pbar = tqdm(loader, desc="  Train", leave=False, ncols=90)
    for images, labels in pbar:
        images = images.to(device, non_blocking=True)
        labels = labels.to(device, non_blocking=True)

        optimizer.zero_grad(set_to_none=True)

        with autocast():
            logits = model(images)
            loss = criterion(logits, labels)

        scaler.scale(loss).backward()

        # Gradient Clipping
        scaler.unscale_(optimizer)
        torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)

        scaler.step(optimizer)
        scaler.update()

        # Metrics
        total_loss += loss.item()
        _, predicted = torch.max(logits, 1)
        correct += (predicted == labels).sum().item()
        total += labels.size(0)

        pbar.set_postfix({
            'loss': f'{loss.item():.4f}',
            'acc': f'{100 * correct / total:.2f}%'
        })

    avg_loss = total_loss / len(loader)
    avg_acc = 100 * correct / total

    return {'loss': avg_loss, 'acc': avg_acc}


def evaluate(model, loader, criterion, device) -> dict:
    """Evaluate model on validation/test set"""
    model.eval()
    total_loss = 0.0
    correct = 0
    total = 0

    with torch.no_grad():
        pbar = tqdm(loader, desc="  Eval", leave=False, ncols=90)
        for images, labels in pbar:
            images = images.to(device, non_blocking=True)
            labels = labels.to(device, non_blocking=True)

            with autocast():
                logits = model(images)
                loss = criterion(logits, labels)

            total_loss += loss.item()
            _, predicted = torch.max(logits, 1)
            correct += (predicted == labels).sum().item()
            total += labels.size(0)

            pbar.set_postfix({'loss': f'{loss.item():.4f}'})

    avg_loss = total_loss / len(loader)
    avg_acc = 100 * correct / total

    return {'loss': avg_loss, 'acc': avg_acc}


# ─── Learning Rate Scheduler ──────────────────────────────────────────────

def get_scheduler(optimizer, epochs, warmup_epochs, min_lr):
    """Cosine annealing with warmup"""
    def lr_lambda(epoch):
        if epoch < warmup_epochs:
            return (epoch + 1) / warmup_epochs
        else:
            progress = (epoch - warmup_epochs) / (epochs - warmup_epochs)
            return max(min_lr, 0.5 * (1 + np.cos(np.pi * progress)))

    from torch.optim.lr_scheduler import LambdaLR
    return LambdaLR(optimizer, lr_lambda)


# ─── Training Loop ────────────────────────────────────────────────────────

def train(
    model, train_loader, val_loader, test_loader,
    num_epochs, learning_rate, weight_decay,
    device, output_dir,
) -> dict:
    """Full training pipeline"""

    criterion = SmoothCrossEntropy(smoothing=0.1)
    optimizer = torch.optim.AdamW(
        model.parameters(),
        lr=learning_rate,
        weight_decay=weight_decay
    )
    scaler = GradScaler()
    scheduler = get_scheduler(
        optimizer,
        epochs=num_epochs,
        warmup_epochs=5,
        min_lr=1e-6
    )

    history = {
        'train_loss': [],
        'train_acc': [],
        'val_loss': [],
        'val_acc': [],
    }

    best_val_loss = float('inf')
    patience_counter = 0
    patience = 7

    for epoch in range(num_epochs):
        print(f"\nEpoch {epoch+1}/{num_epochs}")
        print("-" * 50)

        # Train
        train_metrics = train_one_epoch(
            model, train_loader, optimizer, criterion, scaler, device
        )

        # Validate
        val_metrics = evaluate(model, val_loader, criterion, device)

        # Schedule
        scheduler.step()

        # History
        history['train_loss'].append(train_metrics['loss'])
        history['train_acc'].append(train_metrics['acc'])
        history['val_loss'].append(val_metrics['loss'])
        history['val_acc'].append(val_metrics['acc'])

        print(f"Train Loss: {train_metrics['loss']:.4f} | Train Acc: {train_metrics['acc']:.2f}%")
        print(f"Val Loss: {val_metrics['loss']:.4f} | Val Acc: {val_metrics['acc']:.2f}%")

        # Save best model
        if val_metrics['loss'] < best_val_loss:
            best_val_loss = val_metrics['loss']
            patience_counter = 0
            save_checkpoint(
                model, optimizer, epoch,
                history,
                Path(output_dir) / 'best_model.pth'
            )
            print(f"✓ Best model saved (Val Loss: {val_metrics['loss']:.4f})")
        else:
            patience_counter += 1
            if patience_counter >= patience:
                print(f"\n⚠️ Early stopping triggered (patience: {patience})")
                break

    # Load best model and evaluate on test set
    print("\n" + "="*50)
    print("Testing best model...")
    checkpoint = torch.load(Path(output_dir) / 'best_model.pth')
    model.load_state_dict(checkpoint['model_state_dict'])
    test_metrics = evaluate(model, test_loader, criterion, device)
    print(f"Test Loss: {test_metrics['loss']:.4f} | Test Acc: {test_metrics['acc']:.2f}%")

    history['test_loss'] = test_metrics['loss']
    history['test_acc'] = test_metrics['acc']

    return history, model


# ─── Plotting ──────────────────────────────────────────────────────────────

def plot_training_curves(history, output_dir):
    """Plot and save training curves"""
    fig, axes = plt.subplots(1, 2, figsize=(12, 4))

    # Loss
    axes[0].plot(history['train_loss'], label='Train')
    axes[0].plot(history['val_loss'], label='Val')
    axes[0].set_xlabel('Epoch')
    axes[0].set_ylabel('Loss')
    axes[0].set_title('Training & Validation Loss')
    axes[0].legend()
    axes[0].grid()

    # Accuracy
    axes[1].plot(history['train_acc'], label='Train')
    axes[1].plot(history['val_acc'], label='Val')
    axes[1].set_xlabel('Epoch')
    axes[1].set_ylabel('Accuracy (%)')
    axes[1].set_title('Training & Validation Accuracy')
    axes[1].legend()
    axes[1].grid()

    plt.tight_layout()
    output_path = Path(output_dir) / 'training_curves.png'
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"✓ Training curves saved → {output_path}")
    plt.close()


# ─── Main ──────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='Train plant disease classifier')
    parser.add_argument('--arch', type=str, default=DEFAULTS['arch'], 
                       help='Model architecture')
    parser.add_argument('--epochs', type=int, default=DEFAULTS['epochs'], 
                       help='Number of epochs')
    parser.add_argument('--batch-size', type=int, default=DEFAULTS['batch_size'], 
                       help='Batch size')
    parser.add_argument('--lr', type=float, default=DEFAULTS['lr'], 
                       help='Learning rate')
    parser.add_argument('--img-size', type=int, default=DEFAULTS['img_size'], 
                       help='Image size')
    parser.add_argument('--data-dir', type=str, default=DEFAULTS['data_dir'], 
                       help='Data directory')
    parser.add_argument('--output-dir', type=str, default=DEFAULTS['output_dir'], 
                       help='Output directory')
    parser.add_argument('--device', type=str, 
                       default='cuda' if torch.cuda.is_available() else 'cpu',
                       help='Device: cuda or cpu')
    args = parser.parse_args()

    device = torch.device(args.device)

    print("=" * 50)
    print("Plant Disease Classification - Training")
    print("=" * 50)
    print(f"Device: {device}")
    print(f"Epochs: {args.epochs}")
    print(f"Batch size: {args.batch_size}")
    print(f"Learning rate: {args.lr}")
    print(f"Image size: {args.img_size}")
    print("=" * 50 + "\n")

    # Create dataloaders
    loaders = create_dataloaders(
        data_dir=Path(args.data_dir),
        img_size=args.img_size,
        batch_size=args.batch_size,
        num_workers=DEFAULTS['num_workers']
    )
    print(f"✓ Data loaded")
    print(f"  Train: {len(loaders['train'].dataset)} | Val: {len(loaders['val'].dataset)} | Test: {len(loaders['test'].dataset)}")
    print(f"  Classes: {loaders['num_classes']}\n")

    # Create model
    model = PlantDiseaseModel(
        num_classes=loaders['num_classes'],
        arch=args.arch
    ).to(device)
    total_params = sum(p.numel() for p in model.parameters())
    print(f"✓ Model created")
    print(f"  Total parameters: {total_params:,}\n")

    # Train
    history, model = train(
        model,
        loaders['train'],
        loaders['val'],
        loaders['test'],
        num_epochs=args.epochs,
        learning_rate=args.lr,
        weight_decay=1e-4,
        device=device,
        output_dir=args.output_dir
    )

    # Save history
    output_dir = Path(args.output_dir)
    output_dir.mkdir(exist_ok=True)
    with open(output_dir / 'report.json', 'w') as f:
        json.dump(history, f, indent=2)
    print(f"✓ Report saved → {output_dir / 'report.json'}")

    # Plot
    plot_training_curves(history, args.output_dir)

    # Export ONNX
    export_onnx(model, output_dir / 'plant_disease_model.onnx', img_size=args.img_size)

    print("\n✅ Training complete!")

if __name__ == '__main__':
    main()
