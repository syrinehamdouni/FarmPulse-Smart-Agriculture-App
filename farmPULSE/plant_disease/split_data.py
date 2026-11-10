"""
split_data.py
=============
Split data from data/raw to data/split/{train,val,test}
"""

import json
import shutil
from pathlib import Path
from collections import Counter

import numpy as np
from sklearn.model_selection import train_test_split
from tqdm import tqdm

# ─── Configuration ────────────────────────────────────────────────────────────

DATA_RAW   = Path("data/raw")
DATA_SPLIT = Path("data/split")

TRAIN_RATIO = 0.75  # 75% train
VAL_RATIO   = 0.15  # 15% val
TEST_RATIO  = 0.10  # 10% test

RANDOM_SEED = 42

# ─── Main ────────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("تقسيم البيانات من data/raw إلى data/split")
    print("=" * 60)

    # التأكد من وجود المجلدات
    if not DATA_RAW.exists():
        print(f"❌ {DATA_RAW} غير موجود!")
        return
    
    DATA_SPLIT.mkdir(parents=True, exist_ok=True)
    train_dir = DATA_SPLIT / "train"
    val_dir   = DATA_SPLIT / "val"
    test_dir  = DATA_SPLIT / "test"
    
    train_dir.mkdir(exist_ok=True)
    val_dir.mkdir(exist_ok=True)
    test_dir.mkdir(exist_ok=True)

    # بناء class_info.json
    print("\n📋 بناء معلومات الفئات...")
    class_info = {}
    class_idx = 0

    # جمع جميع الصور من كل فئة
    all_samples = []
    
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

        # جمع الصور من هذه الفئة
        images = []
        for ext in ["*.jpg", "*.JPG", "*.jpeg", "*.JPEG", "*.png", "*.PNG"]:
            images.extend(list(class_dir.glob(ext)))

        for img_path in images:
            all_samples.append((img_path, class_idx))

        print(f"  ✓ {cls_name}: {len(images)} images (ID: {class_idx})")
        class_idx += 1

    print(f"\n📊 الإجمالي: {len(all_samples)} صورة من {class_idx} فئة\n")

    # حفظ class_info.json
    class_info_path = Path("data/class_info.json")
    with open(class_info_path, "w", encoding="utf-8") as f:
        json.dump(class_info, f, ensure_ascii=False, indent=2)
    print(f"✅ تم حفظ {class_info_path}")

    # تقسيم البيانات
    print("\n" + "=" * 60)
    print("Splitting data...")
    print("=" * 60)

    # Train/Test split (75%/25%)
    train_samples, test_samples = train_test_split(
        all_samples,
        test_size=TEST_RATIO,
        random_state=RANDOM_SEED,
        stratify=[lbl for _, lbl in all_samples],
    )

    # Train/Val split من الـ Train (75% train من 75% الكل = 75*0.8 = 60%)
    train_samples, val_samples = train_test_split(
        train_samples,
        test_size=VAL_RATIO / (TRAIN_RATIO + VAL_RATIO),  # ~0.167 (15% من 90%)
        random_state=RANDOM_SEED,
        stratify=[lbl for _, lbl in train_samples],
    )

    print(f"  Train: {len(train_samples)} صورة ({100*len(train_samples)/len(all_samples):.1f}%)")
    print(f"  Val:   {len(val_samples)} صورة ({100*len(val_samples)/len(all_samples):.1f}%)")
    print(f"  Test:  {len(test_samples)} صورة ({100*len(test_samples)/len(all_samples):.1f}%)")

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
        
        print(f"\n📂 {split_name.upper()}:")
        pbar = tqdm(split_samples, desc=f"  Copying", ncols=70)
        
        for src_path, label in pbar:
            # الحصول على اسم الفئة
            cls_name = src_path.parent.name
            cls_dst = split_dst / cls_name
            cls_dst.mkdir(exist_ok=True)
            
            # نسخ الصورة
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
        print(f"  الإجمالي: {total} صورة")
        print(f"  الفئات: {len(stats[split])}")
        
        # أقل وأكثر فئة
        if stats[split]:
            min_cls = min(stats[split], key=stats[split].get)
            max_cls = max(stats[split], key=stats[split].get)
            print(f"  أقل: {min_cls} ({stats[split][min_cls]})")
            print(f"  أكثر: {max_cls} ({stats[split][max_cls]})")

    print("\n" + "=" * 60)
    print("✅ Split complete!")
    print("=" * 60)

if __name__ == "__main__":
    main()
