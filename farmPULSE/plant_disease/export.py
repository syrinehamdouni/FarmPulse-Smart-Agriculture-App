import json
import torch
from model import create_model, export_onnx

# load checkpoint
checkpoint = torch.load("outputs/best_model.pth", map_location="cpu")

# load number of classes
with open("data/class_info.json") as f:
    class_info = json.load(f)

num_classes = len(class_info)

# build model
model = create_model(num_classes=num_classes)

# load weights
if "model_state_dict" in checkpoint:
    model.load_state_dict(checkpoint["model_state_dict"])
elif "state_dict" in checkpoint:
    model.load_state_dict(checkpoint["state_dict"])
else:
    model.load_state_dict(checkpoint)

model.eval()

# export
export_onnx(model, "outputs/plant_disease_model.onnx", img_size=224)

print("✅ ONNX exported successfully!")