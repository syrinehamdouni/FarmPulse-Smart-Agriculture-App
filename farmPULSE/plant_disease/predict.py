"""
predict.py
==========
Diagnose new plant images using trained model.
Supports:
  - Single image
  - Full folder
  - Test-Time Augmentation (TTA)
  - Grad-CAM for visual explanation

Usage:
    # Single image:
    python predict.py --image path/to/leaf.jpg

    # Full folder:
    python predict.py --folder path/to/images/ --output results/

    # With Grad-CAM:
    python predict.py --image leaf.jpg --gradcam

    # With TTA:
    python predict.py --image leaf.jpg --tta
"""

import argparse
import json
from pathlib import Path
from typing import Optional

import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image
import matplotlib.pyplot as plt

from dataset import get_val_transforms, get_tta_transforms
from model import PlantDiseaseModel


# ─── Predictor Class ──────────────────────────────────────────────────────

class PlantDiseasePredictor:
    """Diagnosis engine for plant disease images"""

    def __init__(
        self,
        checkpoint_path: Path,
        class_info_path: Path = Path("data/class_info.json"),
        device: Optional[torch.device] = None,
        img_size: int = 224,
    ):
        self.device = device or torch.device(
            "cuda" if torch.cuda.is_available() else "cpu"
        )
        self.img_size = img_size

        # Load class info
        with open(class_info_path, 'r') as f:
            self.class_info = json.load(f)

        self.idx_to_class = {
            v["id"]: k for k, v in self.class_info.items()
        }
        self.num_classes = len(self.class_info)

        # Load model
        self.model = self._load_model(checkpoint_path)
        self.val_transform = get_val_transforms(img_size)
        self.tta_transforms = get_tta_transforms(img_size)

        print(f"✓ Model loaded | {self.num_classes} classes | device: {self.device}")

    def _load_model(self, checkpoint_path):
        """Load model weights"""
        model = PlantDiseaseModel(
            num_classes=self.num_classes,
            arch="efficientnet_b3"
        ).to(self.device)

        checkpoint = torch.load(checkpoint_path, map_location=self.device)
        model.load_state_dict(checkpoint['model_state_dict'])
        model.eval()

        return model

    # ─── Image Preparation ────────────────────────────────────────────────
    def _load_image(self, path: Path) -> np.ndarray:
        """Load image from disk"""
        img = Image.open(path).convert("RGB")
        return np.array(img)

    def _apply_transform(self, img_np: np.ndarray, transform) -> torch.Tensor:
        """Apply augmentation and convert to tensor"""
        out = transform(image=img_np)["image"]
        return out.unsqueeze(0).to(self.device)

    # ─── Prediction ───────────────────────────────────────────────────────
    @torch.inference_mode()
    def predict(
        self,
        image_path: Path,
        top_k: int = 5,
        use_tta: bool = False,
    ) -> dict:
        """Predict disease from image"""
        img_np = self._load_image(image_path)

        if use_tta:
            logits_list = []
            for tf in self.tta_transforms:
                tensor = self._apply_transform(img_np, tf)
                logits_list.append(self.model(tensor))
            logits = torch.stack(logits_list).mean(0)
        else:
            tensor = self._apply_transform(img_np, self.val_transform)
            logits = self.model(tensor)

        probs = torch.softmax(logits, dim=1)[0]
        top_probs, top_indices = torch.topk(probs, k=min(top_k, self.num_classes))

        predictions = {}
        for rank, (prob, idx) in enumerate(zip(top_probs, top_indices)):
            cls_name = self.idx_to_class[idx.item()]
            cls_data = self.class_info[cls_name]
            predictions[rank + 1] = {
                'class': cls_name,
                'probability': float(prob.item()),
                'plant': cls_data['plant'],
                'disease': cls_data['disease'],
                'is_healthy': cls_data['is_healthy']
            }

        return predictions

    @torch.inference_mode()
    def predict_batch(self, image_paths: list) -> dict:
        """Predict on multiple images"""
        results = {}
        for img_path in image_paths:
            results[img_path.name] = self.predict(img_path)
        return results


# ─── Visualization ────────────────────────────────────────────────────────

def visualize_predictions(image_path: Path, predictions: dict, output_path=None):
    """Visualize predictions on image"""
    img = Image.open(image_path)

    fig, ax = plt.subplots(1, 1, figsize=(10, 8))
    ax.imshow(img)
    ax.axis('off')

    # Add text
    top_pred = predictions[1]
    text = f"Predicted: {top_pred['disease']} ({top_pred['plant']})\n"
    text += f"Confidence: {top_pred['probability']:.2%}\n"
    text += f"Healthy: {'Yes' if top_pred['is_healthy'] else 'No'}"

    ax.text(
        0.5, -0.1, text,
        transform=ax.transAxes,
        ha='center',
        fontsize=12,
        bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.8)
    )

    plt.tight_layout()

    if output_path:
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        print(f"✓ Visualization saved → {output_path}")
    else:
        plt.show()

    plt.close()


# ─── Main ──────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='Predict plant disease from images')
    parser.add_argument('--image', type=str, help='Path to single image')
    parser.add_argument('--folder', type=str, help='Path to folder with images')
    parser.add_argument('--model', type=str, default='outputs/best_model.pth', 
                       help='Model checkpoint path')
    parser.add_argument('--output', type=str, default=None, 
                       help='Output directory for results')
    parser.add_argument('--tta', action='store_true', 
                       help='Use Test-Time Augmentation')
    parser.add_argument('--visualize', action='store_true', 
                       help='Save visualization images')
    parser.add_argument('--top-k', type=int, default=5, 
                       help='Show top-k predictions')
    args = parser.parse_args()

    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

    # Load predictor
    predictor = PlantDiseasePredictor(
        Path(args.model),
        device=device
    )

    if args.image:
        # Single image
        image_path = Path(args.image)
        predictions = predictor.predict(image_path, top_k=args.top_k, use_tta=args.tta)

        print(f"\n📊 Predictions for {image_path.name}:")
        for rank, pred in predictions.items():
            print(f"  {rank}. {pred['disease']} ({pred['plant']}): {pred['probability']:.2%}")

        if args.visualize:
            output = Path(args.output) / f"{image_path.stem}_pred.png" if args.output else None
            visualize_predictions(image_path, predictions, output)

    elif args.folder:
        # Batch prediction
        folder_path = Path(args.folder)
        image_paths = list(folder_path.glob('*.jpg')) + list(folder_path.glob('*.png'))

        print(f"\nProcessing {len(image_paths)} images...")
        results = predictor.predict_batch(image_paths)

        # Save results
        if args.output:
            output_dir = Path(args.output)
            output_dir.mkdir(exist_ok=True)

            with open(output_dir / 'predictions.json', 'w') as f:
                json.dump(results, f, indent=2)
            print(f"✓ Results saved → {output_dir / 'predictions.json'}")

    else:
        print("Provide either --image or --folder")

if __name__ == '__main__':
    main()
