"""
dataset.py
==========
PyTorch Dataset with strong Augmentation for PlantVillage.
"""

import json
from pathlib import Path
from typing import Optional, Callable, Tuple

import numpy as np
from PIL import Image
import torch
from torch.utils.data import Dataset, DataLoader, WeightedRandomSampler

import albumentations as A
from albumentations.pytorch import ToTensorV2


# ─── Augmentation Pipelines ───────────────────────────────────────────────

def get_train_transforms(img_size: int = 224) -> A.Compose:
    return A.Compose([
        A.RandomResizedCrop(size=(img_size, img_size), scale=(0.7, 1.0)),

        A.HorizontalFlip(p=0.5),
        A.VerticalFlip(p=0.3),
        A.RandomRotate90(p=0.5),

        A.ShiftScaleRotate(
            shift_limit=0.05,
            scale_limit=0.1,
            rotate_limit=20,
            p=0.5
        ),

        # Color augmentation
        A.OneOf([
            A.HueSaturationValue(
                hue_shift_limit=15,
                sat_shift_limit=25,
                val_shift_limit=15,
                p=1.0
            ),
            A.RGBShift(
                r_shift_limit=15,
                g_shift_limit=15,
                b_shift_limit=15,
                p=1.0
            ),
        ], p=0.6),

        A.RandomBrightnessContrast(
            brightness_limit=0.2,
            contrast_limit=0.2,
            p=0.5
        ),

        A.CLAHE(clip_limit=3.0, p=0.3),

        # Noise & Blur
        A.OneOf([
            A.GaussNoise(var_limit=(10.0, 50.0), p=1.0),
            A.GaussianBlur(blur_limit=(3, 5), p=1.0),
            A.MotionBlur(blur_limit=5, p=1.0),
        ], p=0.3),

        # Regularization
        A.CoarseDropout(
            max_holes=8,
            max_height=img_size // 8,
            max_width=img_size // 8,
            fill_value=0,
            p=0.3
        ),

        A.Normalize(
            mean=[0.485, 0.456, 0.406],
            std=[0.229, 0.224, 0.225]
        ),

        ToTensorV2(),
    ])


def get_val_transforms(img_size: int = 224) -> A.Compose:
    return A.Compose([
        A.Resize(height=img_size + 32, width=img_size + 32),
        A.CenterCrop(height=img_size, width=img_size),

        A.Normalize(
            mean=[0.485, 0.456, 0.406],
            std=[0.229, 0.224, 0.225]
        ),

        ToTensorV2(),
    ])


def get_tta_transforms(img_size: int = 224) -> list:
    base = [
        A.Resize(height=img_size + 32, width=img_size + 32),
        A.Normalize(
            mean=[0.485, 0.456, 0.406],
            std=[0.229, 0.224, 0.225]
        ),
        ToTensorV2(),
    ]

    return [
        A.Compose([
            A.Resize(height=img_size + 32, width=img_size + 32),
            A.CenterCrop(height=img_size, width=img_size),
            *base[1:]
        ]),
        A.Compose([
            A.Resize(height=img_size + 32, width=img_size + 32),
            A.CenterCrop(height=img_size, width=img_size),
            A.HorizontalFlip(p=1.0),
            *base[1:]
        ]),
        A.Compose([
            A.RandomResizedCrop(size=(img_size, img_size), scale=(0.9, 1.0)),
            *base[1:]
        ]),
    ]


# ─── Dataset Class ────────────────────────────────────────────────────────

class PlantDiseaseDataset(Dataset):

    def __init__(
        self,
        split_dir: Path,
        class_info_path: Path = Path("data/class_info.json"),
        transform: Optional[Callable] = None,
        cache_images: bool = False,
    ):
        self.split_dir = Path(split_dir)
        self.transform = transform
        self.cache = {}
        self.do_cache = cache_images

        with open(class_info_path, encoding="utf-8") as f:
            self.class_info = json.load(f)

        self.class_to_idx = {c: v["id"] for c, v in self.class_info.items()}
        self.idx_to_class = {v: k for k, v in self.class_to_idx.items()}
        self.num_classes = len(self.class_to_idx)

        self.samples: list[Tuple[Path, int]] = []

        for cls_dir in sorted(self.split_dir.iterdir()):
            if not cls_dir.is_dir():
                continue

            cls_name = cls_dir.name
            if cls_name not in self.class_to_idx:
                continue

            label = self.class_to_idx[cls_name]

            for img_path in cls_dir.glob("*"):
                if img_path.suffix.lower() in (".jpg", ".jpeg", ".png"):
                    self.samples.append((img_path, label))

        if not self.samples:
            raise ValueError(f"No images found in {split_dir}")

        print(f"[{split_dir.name}] {len(self.samples):,} images | {self.num_classes} classes")

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx: int):
        path, label = self.samples[idx]

        if self.do_cache and idx in self.cache:
            image = self.cache[idx]
        else:
            image = np.array(Image.open(path).convert("RGB"))
            if self.do_cache:
                self.cache[idx] = image

        if self.transform:
            image = self.transform(image=image)["image"]

        return image, label

    def get_class_weights(self):
        counts = torch.zeros(self.num_classes)

        for _, label in self.samples:
            counts[label] += 1

        weights_per_class = 1.0 / (counts + 1e-6)

        sample_weights = torch.tensor([
            weights_per_class[label] for _, label in self.samples
        ])

        return sample_weights


# ─── DataLoader Factory ───────────────────────────────────────────────────

def create_dataloaders(
    data_dir: Path = Path("data/split"),
    img_size: int = 224,
    batch_size: int = 32,
    num_workers: int = 2,
    use_weighted_sampler: bool = True,
):

    print("\n📦 Building datasets...")

    train_ds = PlantDiseaseDataset(data_dir / "train", transform=get_train_transforms(img_size))
    val_ds   = PlantDiseaseDataset(data_dir / "val",   transform=get_val_transforms(img_size))
    test_ds  = PlantDiseaseDataset(data_dir / "test",  transform=get_val_transforms(img_size))

    if use_weighted_sampler:
        weights = train_ds.get_class_weights()
        sampler = WeightedRandomSampler(weights, len(weights), replacement=True)
        shuffle = False
    else:
        sampler = None
        shuffle = True

    loaders = {
        "train": DataLoader(
            train_ds,
            batch_size=batch_size,
            sampler=sampler,
            shuffle=shuffle,
            num_workers=num_workers,
            pin_memory=True,
            drop_last=True,
        ),

        "val": DataLoader(
            val_ds,
            batch_size=batch_size * 2,
            shuffle=False,
            num_workers=num_workers,
            pin_memory=True,
        ),

        "test": DataLoader(
            test_ds,
            batch_size=batch_size * 2,
            shuffle=False,
            num_workers=num_workers,
            pin_memory=True,
        ),

        "num_classes": train_ds.num_classes,
        "class_info": train_ds.class_info,
    }

    return loaders