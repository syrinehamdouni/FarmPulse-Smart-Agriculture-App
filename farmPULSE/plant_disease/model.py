"""
model.py
========
Transfer Learning models for plant disease classification.
Supports: EfficientNet-B3, ResNet50, MobileNetV3, ViT-Small
"""

import json
from pathlib import Path
from typing import Optional

import torch
import torch.nn as nn
import timm


# ─── Available Models ─────────────────────────────────────────────────────
AVAILABLE_MODELS = {
    "efficientnet_b3":   "efficientnet_b3",          # High accuracy (default)
    "efficientnet_b0":   "efficientnet_b0",           # Fast and lightweight
    "resnet50":          "resnet50",                  # Classic and reliable
    "mobilenetv3":       "mobilenetv3_large_100",     # For mobile / edge
    "convnext_tiny":     "convnext_tiny",             # Modern and powerful
    "vit_small":         "vit_small_patch16_224",     # Vision Transformer
}


# ─── Model Building ───────────────────────────────────────────────────────

class PlantDiseaseModel(nn.Module):
    """
    Transfer Learning model with:
    - Frozen backbone initially (warm-up)
    - Custom head with Dropout for regularization
    - Label Smoothing in loss
    """

    def __init__(
        self,
        num_classes:  int,
        arch:         str   = "efficientnet_b3",
        pretrained:   bool  = True,
        dropout:      float = 0.4,
        freeze_until: str   = "none",  # "all" | "none" | "layer3"
    ):
        super().__init__()
        self.arch        = arch
        self.num_classes = num_classes

        timm_name = AVAILABLE_MODELS.get(arch, arch)
        self.backbone = timm.create_model(
            timm_name,
            pretrained=pretrained,
            num_classes=0,          # Remove original head
        )
        in_features = self.backbone.num_features

        # ─── Custom Head ──────────────────────────────────────────────────
        self.head = nn.Sequential(
            nn.AdaptiveAvgPool2d(1) if self._needs_pool() else nn.Identity(),
            nn.Flatten(),
            nn.BatchNorm1d(in_features),
            nn.Dropout(dropout),
            nn.Linear(in_features, 512),
            nn.GELU(),
            nn.BatchNorm1d(512),
            nn.Dropout(dropout / 2),
            nn.Linear(512, num_classes),
        )

        # ─── Initialize Head ──────────────────────────────────────────────
        for m in self.head.modules():
            if isinstance(m, nn.Linear):
                nn.init.kaiming_normal_(m.weight, mode="fan_out")
                if m.bias is not None:
                    nn.init.zeros_(m.bias)

        self._freeze(freeze_until)

    def _needs_pool(self) -> bool:
        """Some models have global pool, others don't"""
        try:
            dummy = torch.zeros(1, 3, 224, 224)
            out   = self.backbone(dummy)
            return out.dim() > 2
        except Exception:
            return False

    def _freeze(self, mode: str):
        if mode == "all":
            for p in self.backbone.parameters():
                p.requires_grad = False
            print("  Backbone: FROZEN (training head only)")
        elif mode == "none":
            print("  Backbone: fully trainable")
        else:
            # Freeze up to a specific layer (e.g., "layer3" in ResNet)
            freeze = True
            for name, param in self.backbone.named_parameters():
                if mode in name:
                    freeze = False
                param.requires_grad = freeze
            print(f"  Backbone: partial freeze (up to {mode})")

    def forward(self, x):
        features = self.backbone(x)
        logits = self.head(features)
        return logits

    def extract_features(self, x):
        return self.backbone(x)


# ─── Loss Functions ───────────────────────────────────────────────────────

class SmoothCrossEntropy(nn.Module):
    """Cross entropy with label smoothing"""

    def __init__(self, smoothing=0.1):
        super().__init__()
        self.smoothing = smoothing
        self.ce = nn.CrossEntropyLoss(reduction='none')

    def forward(self, logits, target):
        batch_size = logits.size(0)
        num_classes = logits.size(1)

        # One-hot encode and apply label smoothing
        one_hot = torch.zeros(batch_size, num_classes, device=logits.device)
        one_hot.scatter_(1, target.unsqueeze(1), 1.0)
        one_hot = one_hot * (1 - self.smoothing) + self.smoothing / num_classes

        # Compute loss
        log_probs = torch.log_softmax(logits, dim=1)
        loss = -(one_hot * log_probs).sum(1).mean()

        return loss


# ─── Utilities ─────────────────────────────────────────────────────────────

def mixup_data(x, y, alpha=0.4):
    """Mixup augmentation"""
    if alpha > 0:
        lam = np.random.beta(alpha, alpha)
    else:
        lam = 1

    batch_size = x.size(0)
    index = torch.randperm(batch_size)

    mixed_x = lam * x + (1 - lam) * x[index, :]
    y_a, y_b = y, y[index]

    return mixed_x, y_a, y_b, lam


def mixup_criterion(criterion, pred, y_a, y_b, lam):
    """Compute mixup loss"""
    return lam * criterion(pred, y_a) + (1 - lam) * criterion(pred, y_b)


def save_checkpoint(model, optimizer, epoch, metrics, path):
    """Save model checkpoint"""
    torch.save({
        'epoch': epoch,
        'model_state_dict': model.state_dict(),
        'optimizer_state_dict': optimizer.state_dict(),
        'metrics': metrics,
    }, path)


def export_onnx(model, output_path, img_size=224):
    """Export model to ONNX format"""
    dummy_input = torch.randn(1, 3, img_size, img_size)
    torch.onnx.export(
        model,
        dummy_input,
        str(output_path),
        input_names=['image'],
        output_names=['logits'],
        opset_version=12,
    )
    print(f"✓ Model exported to {output_path}")


# ─── Model Factory ────────────────────────────────────────────────────────

def create_model(
    num_classes: int,
    arch: str = 'efficientnet_b3',
    pretrained: bool = True,
    device: str = 'cuda' if torch.cuda.is_available() else 'cpu'
) -> PlantDiseaseModel:
    """Create and return model on specified device"""
    model = PlantDiseaseModel(num_classes=num_classes, arch=arch, pretrained=pretrained)
    model = model.to(device)
    return model
