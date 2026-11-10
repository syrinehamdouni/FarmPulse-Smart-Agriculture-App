"""
download_data.py
================
Download and split plant disease dataset from Kaggle
(or if data already exists, just split it)
"""

import json
import shutil
import argparse
import subprocess
from pathlib import Path
from collections import Counter

import numpy as np
from sklearn.model_selection import train_test_split
from tqdm import tqdm

# ─── Configuration ──────────────────────────────────────────────────────

DATASET_ID = "emmarex/plantdisease"
DATA_RAW   = Path("data/raw")
DATA_SPLIT = Path("data/split")

TRAIN_RATIO = 0.75  # 75% train
VAL_RATIO   = 0.15  # 15% val
TEST_RATIO  = 0.10  # 10% test

RANDOM_SEED = 42

# ─── Kaggle Setup ────────────────────────────────────────────────────────

def setup_kaggle_credentials(username: str, api_key: str):
    """Save Kaggle API credentials"""
    kaggle_dir = Path.home() / ".kaggle"
    kaggle_dir.mkdir(exist_ok=True)
    
    cred = {"username": username, "key": api_key}
    cred_file = kaggle_dir / "kaggle.json"
    
    with open(cred_file, "w") as f:
        json.dump(cred, f)
    
    cred_file.chmod(0o600)
    print(f"✅ Kaggle credentials saved → {cred_file}")

def download_from_kaggle():
    """Download dataset from Kaggle"""
    print("\n" + "=" * 60)
    print(f"📥 Downloading {DATASET_ID}...")
    print("=" * 60)
    
    DATA_RAW.mkdir(parents=True, exist_ok=True)
    
    try:
        cmd = f"kaggle datasets download -d {DATASET_ID} -p {DATA_RAW} --unzip"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Download successful!")
            return True
        else:
            print(f"❌ Download error: {result.stderr}")
            return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

# ─── Build Class Info ────────────────────────────────────────────────────

def build_class_info():
    """Build class information dictionary"""
    print("\n" + "=" * 60)
    print("📋 Building class info...")
    print("=" * 60)
    
    class_info = {}
    class_idx = 0

    for class_dir in sorted(DATA_RAW.iterdir()):
        if not class_dir.is_dir():
            continue

        cls_name = class_dir.name
        
        # Parse class name
        if "___" in cls_name:
            parts = cls_name.split("___")
            plant = parts[0].replace("_", " ")
            disease = parts[1].replace("_", " ")
        elif "__" in cls_name:
            parts = cls_name.split("__")
            plant = parts[0].replace("_", " ")
            disease = parts[1].replace("_", " ")
        else:
            plant = cls_name.replace("_", " ")
            disease = "Unknown"

        is_healthy = "healthy" in disease.lower()

        class_info[cls_name] = {
            "id": class_idx,
            "plant": plant,
            "disease": disease,
            "is_healthy": is_healthy,
        }

        # Count images
        images = []
        for ext in ["*.jpg", "*.JPG", "*.jpeg", "*.JPEG", "*.png", "*.PNG"]:
            images.extend(list(class_dir.glob(ext)))

        print(f"  ✓ {cls_name}: {len(images)} images (ID: {class_idx})")
        class_idx += 1

    # Save
    class_info_path = Path("data/class_info.json")
    with open(class_info_path, "w", encoding="utf-8") as f:
        json.dump(class_info, f, ensure_ascii=False, indent=2)
    
    print(f"\n✅ {class_info_path} ({class_idx} classes)")
    return class_info

# ─── Split Dataset ──────────────────────────────────────────────────────

def split_dataset(class_info: dict):
    """Split data into train/val/test sets"""
    print("\n" + "=" * 60)
    print("✂️ Splitting data...")
    print("=" * 60)

    # Create directories
    DATA_SPLIT.mkdir(parents=True, exist_ok=True)
    train_dir = DATA_SPLIT / "train"
    val_dir   = DATA_SPLIT / "val"
    test_dir  = DATA_SPLIT / "test"
    
    train_dir.mkdir(exist_ok=True)
    val_dir.mkdir(exist_ok=True)
    test_dir.mkdir(exist_ok=True)

    # Collect all images
    all_samples = []
    
    for class_dir in sorted(DATA_RAW.iterdir()):
        if not class_dir.is_dir():
            continue

        cls_name = class_dir.name
        if cls_name not in class_info:
            continue
        
        class_idx = class_info[cls_name]["id"]
        
        for ext in ["*.jpg", "*.JPG", "*.jpeg", "*.JPEG", "*.png", "*.PNG"]:
            for img_path in class_dir.glob(ext):
                all_samples.append((img_path, class_idx))

    print(f"📊 Total: {len(all_samples)} images\n")

    # Train/Test split
    train_samples, test_samples = train_test_split(
        all_samples,
        test_size=TEST_RATIO,
        random_state=RANDOM_SEED,
        stratify=[lbl for _, lbl in all_samples],
    )

    # Train/Val split
    train_samples, val_samples = train_test_split(
        train_samples,
        test_size=VAL_RATIO / (TRAIN_RATIO + VAL_RATIO),
        random_state=RANDOM_SEED,
        stratify=[lbl for _, lbl in train_samples],
    )

    print(f"  Train: {len(train_samples)} ({100*len(train_samples)/len(all_samples):.1f}%)")
    print(f"  Val:   {len(val_samples)} ({100*len(val_samples)/len(all_samples):.1f}%)")
    print(f"  Test:  {len(test_samples)} ({100*len(test_samples)/len(all_samples):.1f}%)")

    # Copy images
    print("\n" + "=" * 60)
    print("📂 Copying images...")
    print("=" * 60)

    stats = {"train": Counter(), "val": Counter(), "test": Counter()}

    for split_name, split_samples in [
        ("train", train_samples),
        ("val", val_samples),
        ("test", test_samples),
    ]:
        split_dst = DATA_SPLIT / split_name
        
        print(f"\n{split_name.upper()}:")
        pbar = tqdm(split_samples, desc="  Copying", ncols=70)
        
        for src_path, label in pbar:
            cls_name = src_path.parent.name
            cls_dst = split_dst / cls_name
            cls_dst.mkdir(exist_ok=True)
            
            dst_path = cls_dst / src_path.name
            if not dst_path.exists():
                shutil.copy2(src_path, dst_path)
            
            stats[split_name][cls_name] += 1

    # Print statistics
    print("\n" + "=" * 60)
    print("📊 Split Summary:")
    print("=" * 60)
    
    for split in ["train", "val", "test"]:
        print(f"\n{split.upper()}:")
        total = sum(stats[split].values())
        print(f"  Total: {total} images")
        print(f"  Classes: {len(stats[split])}")
        
        if stats[split]:
            min_cls = min(stats[split], key=stats[split].get)
            max_cls = max(stats[split], key=stats[split].get)
            print(f"  Min: {min_cls} ({stats[split][min_cls]})")
            print(f"  Max: {max_cls} ({stats[split][max_cls]})")

# ─── Main ────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Download and split plant disease dataset")
    parser.add_argument("--kaggle-user", type=str, help="Kaggle username")
    parser.add_argument("--kaggle-key", type=str, help="Kaggle API key")
    parser.add_argument("--skip-download", action="store_true", 
                       help="Skip download if data already exists")
    args = parser.parse_args()

    print("\n" + "=" * 60)
    print("🌾 Plant Disease Classification - Download & Split")
    print("=" * 60)

    # Kaggle Credentials
    if args.kaggle_user and args.kaggle_key:
        setup_kaggle_credentials(args.kaggle_user, args.kaggle_key)

    # Download (if not already present)
    if not args.skip_download and not DATA_RAW.exists():
        if not download_from_kaggle():
            print("⚠️ Download failed. Check your Kaggle credentials.")
            return
    elif DATA_RAW.exists():
        print(f"✅ Data already exists at {DATA_RAW}")

    if not DATA_RAW.exists():
        print(f"❌ {DATA_RAW} not found!")
        return

    # Build Class Info
    class_info = build_class_info()

    # Split
    split_dataset(class_info)

    print("\n" + "=" * 60)
    print("✅ Success! Data is ready for training")
    print("=" * 60)
    print("\nNext step:")
    print("  python train.py --epochs 30")

if __name__ == "__main__":
    main()
