from fastapi import FastAPI, File, UploadFile
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image
import io
import json
import cv2
import os
import base64

from model import create_model

app = FastAPI(title="Plant Disease API 🌿🔥")

# Mount static files
os.makedirs("outputs", exist_ok=True)
app.mount("/static", StaticFiles(directory="outputs"), name="static")

# ─── Load class info ───────────────
with open("data/class_info.json") as f:
    class_info = json.load(f)

idx_to_class = {v["id"]: k for k, v in class_info.items()}
num_classes = len(class_info)

# ─── Load PyTorch model ────────────
checkpoint = torch.load("outputs/best_model.pth", map_location="cpu")

model = create_model(num_classes=num_classes)

if "model_state_dict" in checkpoint:
    model.load_state_dict(checkpoint["model_state_dict"])
else:
    model.load_state_dict(checkpoint)

model.eval()


# ─── AI Recommendations Database ────────────────────
RECOMMENDATIONS_DB = {
    "Tomato Early blight": {
        "severity": "High",
        "treatment": [
            "Spray fungicide (Mancozeb or Chlorothalonil) every 7-10 days",
            "Remove infected leaves and stems",
            "Improve air circulation by pruning"
        ],
        "prevention": [
            "Water at the base, not on leaves",
            "Avoid overhead irrigation",
            "Practice crop rotation",
            "Maintain 2-3 feet spacing between plants"
        ],
        "products": ["Mancozeb 75% WP", "Copper Fungicide", "Sulfur Dust"]
    },
    "Tomato Late blight": {
        "severity": "Critical",
        "treatment": [
            "Spray metalaxyl + mancozeb immediately",
            "Remove affected plant parts",
            "Isolate infected plants"
        ],
        "prevention": [
            "Maintain proper spacing",
            "Water early morning",
            "Use resistant varieties",
            "Destroy plant debris"
        ],
        "products": ["Ridomil Gold", "Metalaxyl 8% + Mancozeb 64% WP"]
    },
    "Tomato Septoria leaf spot": {
        "severity": "Medium",
        "treatment": [
            "Remove infected leaves",
            "Spray chlorothalonil or copper fungicide",
            "Increase ventilation"
        ],
        "prevention": [
            "Avoid leaf wetness",
            "Stake plants for better airflow",
            "Mulch soil",
            "Sanitize tools"
        ],
        "products": ["Chlorothalonil 75% WP", "Copper Oxychloride"]
    },
    "Tomato__Bacterial_spot": {
        "severity": "High",
        "treatment": [
            "Spray copper-based bactericide (Copper Hydroxide)",
            "Remove infected leaves and fruit",
            "Isolate infected plants"
        ],
        "prevention": [
            "Use disease-free certified seeds",
            "Avoid overhead irrigation",
            "Maintain 2-3 feet spacing",
            "Sanitize pruning tools with bleach",
            "Rotate crops annually"
        ],
        "products": ["Copper Hydroxide", "Streptomycin", "Oxytetracycline"]
    },
    "Tomato Bacterial spot": {
        "severity": "High",
        "treatment": [
            "Spray copper-based bactericide (Copper Hydroxide)",
            "Remove infected leaves and fruit",
            "Isolate infected plants"
        ],
        "prevention": [
            "Use disease-free certified seeds",
            "Avoid overhead irrigation",
            "Maintain 2-3 feet spacing",
            "Sanitize pruning tools with bleach",
            "Rotate crops annually"
        ],
        "products": ["Copper Hydroxide", "Streptomycin", "Oxytetracycline"]
    },
    "Pepper__bell___Bacterial_spot": {
        "severity": "High",
        "treatment": [
            "Spray copper-based bactericide",
            "Remove infected fruit and leaves",
            "No cure once infected - prevention is key"
        ],
        "prevention": [
            "Use disease-free seeds",
            "Avoid overhead watering",
            "Maintain 2-foot spacing",
            "Sanitize equipment"
        ],
        "products": ["Copper Hydroxide", "Streptomycin + Oxytetracycline"]
    },
    "Potato Early blight": {
        "severity": "High",
        "treatment": [
            "Remove infected leaves",
            "Spray mancozeb or chlorothalonil",
            "Mulch to prevent soil splash"
        ],
        "prevention": [
            "Plant resistant varieties",
            "Proper spacing (2-3 feet)",
            "Remove volunteer potato plants",
            "Avoid overhead irrigation"
        ],
        "products": ["Mancozeb 75% WP", "Chlorothalonil 75% WP"]
    },
    "Tomato Yellow Leaf Curl Virus": {
        "severity": "Critical",
        "treatment": [
            "Remove infected plants immediately",
            "Control whitefly vectors with insecticide",
            "No cure - prevention is essential"
        ],
        "prevention": [
            "Control whiteflies with neem oil",
            "Use reflective mulch",
            "Plant resistant varieties",
            "Eliminate weeds that host whiteflies"
        ],
        "products": ["Neem Oil", "Pyrethrin", "Yellow Sticky Traps"]
    },
    "Tomato Mosaic Virus": {
        "severity": "High",
        "treatment": [
            "Remove infected plants",
            "Sanitize tools between plants (bleach solution)",
            "No cure available"
        ],
        "prevention": [
            "Use resistant varieties",
            "Disinfect tools regularly",
            "Wash hands before handling plants",
            "Remove infected plants immediately"
        ],
        "products": ["Resistant varieties", "Bleach solution for tools"]
    }
}

# ─── Disease Prevalence by Region ──────────────────────────────────────
PREVALENCE_DB = {
    "Tomato Early blight": {
        "Tunisia": {"prevalence_rate": 65, "season": "Spring-Summer", "risk_level": "High"},
        "Egypt": {"prevalence_rate": 45, "season": "Winter-Spring", "risk_level": "Medium"},
        "Morocco": {"prevalence_rate": 70, "season": "Spring-Fall", "risk_level": "High"},
        "Mediterranean": {"prevalence_rate": 72, "season": "Year-round", "risk_level": "Critical"},
        "Middle East": {"prevalence_rate": 38, "season": "Winter", "risk_level": "Medium"}
    },
    "Tomato Late blight": {
        "Tunisia": {"prevalence_rate": 55, "season": "Winter-Spring", "risk_level": "High"},
        "Egypt": {"prevalence_rate": 30, "season": "Winter", "risk_level": "Medium"},
        "Morocco": {"prevalence_rate": 75, "season": "Fall-Winter", "risk_level": "Critical"},
        "Mediterranean": {"prevalence_rate": 80, "season": "Year-round", "risk_level": "Critical"},
        "Middle East": {"prevalence_rate": 25, "season": "Winter", "risk_level": "Low"}
    },
    "Tomato Septoria leaf spot": {
        "Tunisia": {"prevalence_rate": 48, "season": "Spring-Summer", "risk_level": "Medium"},
        "Egypt": {"prevalence_rate": 35, "season": "Spring", "risk_level": "Medium"},
        "Morocco": {"prevalence_rate": 52, "season": "Spring-Summer", "risk_level": "High"},
        "Mediterranean": {"prevalence_rate": 60, "season": "Spring-Fall", "risk_level": "High"},
        "Middle East": {"prevalence_rate": 28, "season": "Spring", "risk_level": "Low"}
    },
    "Tomato__Bacterial_spot": {
        "Tunisia": {"prevalence_rate": 52, "season": "Summer", "risk_level": "High"},
        "Egypt": {"prevalence_rate": 60, "season": "Summer-Fall", "risk_level": "High"},
        "Morocco": {"prevalence_rate": 55, "season": "Summer", "risk_level": "High"},
        "Mediterranean": {"prevalence_rate": 70, "season": "Summer-Fall", "risk_level": "High"},
        "Middle East": {"prevalence_rate": 48, "season": "Summer", "risk_level": "High"}
    },
    "Tomato Bacterial spot": {
        "Tunisia": {"prevalence_rate": 52, "season": "Summer", "risk_level": "High"},
        "Egypt": {"prevalence_rate": 60, "season": "Summer-Fall", "risk_level": "High"},
        "Morocco": {"prevalence_rate": 55, "season": "Summer", "risk_level": "High"},
        "Mediterranean": {"prevalence_rate": 70, "season": "Summer-Fall", "risk_level": "High"},
        "Middle East": {"prevalence_rate": 48, "season": "Summer", "risk_level": "High"}
    },
    "Pepper__bell___Bacterial_spot": {
        "Tunisia": {"prevalence_rate": 42, "season": "Summer", "risk_level": "Medium"},
        "Egypt": {"prevalence_rate": 55, "season": "Summer-Fall", "risk_level": "High"},
        "Morocco": {"prevalence_rate": 48, "season": "Summer", "risk_level": "High"},
        "Mediterranean": {"prevalence_rate": 65, "season": "Summer-Fall", "risk_level": "High"},
        "Middle East": {"prevalence_rate": 50, "season": "Summer", "risk_level": "High"}
    },
    "Potato Early blight": {
        "Tunisia": {"prevalence_rate": 70, "season": "Spring-Summer", "risk_level": "High"},
        "Egypt": {"prevalence_rate": 40, "season": "Winter-Spring", "risk_level": "Medium"},
        "Morocco": {"prevalence_rate": 78, "season": "Spring-Summer", "risk_level": "Critical"},
        "Mediterranean": {"prevalence_rate": 85, "season": "Year-round", "risk_level": "Critical"},
        "Middle East": {"prevalence_rate": 35, "season": "Winter-Spring", "risk_level": "Medium"}
    },
    "Tomato Yellow Leaf Curl Virus": {
        "Tunisia": {"prevalence_rate": 40, "season": "Summer-Fall", "risk_level": "High"},
        "Egypt": {"prevalence_rate": 70, "season": "Summer-Fall", "risk_level": "Critical"},
        "Morocco": {"prevalence_rate": 35, "season": "Summer", "risk_level": "Medium"},
        "Mediterranean": {"prevalence_rate": 45, "season": "Summer-Fall", "risk_level": "High"},
        "Middle East": {"prevalence_rate": 65, "season": "Summer", "risk_level": "High"}
    },
    "Tomato Mosaic Virus": {
        "Tunisia": {"prevalence_rate": 35, "season": "Spring-Summer", "risk_level": "Medium"},
        "Egypt": {"prevalence_rate": 40, "season": "Spring-Summer", "risk_level": "Medium"},
        "Morocco": {"prevalence_rate": 30, "season": "Spring-Summer", "risk_level": "Medium"},
        "Mediterranean": {"prevalence_rate": 50, "season": "Year-round", "risk_level": "High"},
        "Middle East": {"prevalence_rate": 38, "season": "Spring-Summer", "risk_level": "Medium"}
    }
}

# ─── Response Models ───────────────────
class Recommendation(BaseModel):
    """AI Recommendation model"""
    severity: str
    treatment: list
    prevention: list
    products: list


class PrevalenceInfo(BaseModel):
    """Disease prevalence information for a region"""
    prevalence_rate: float  # Percentage
    season: str
    risk_level: str


class DiseaseHotspot(BaseModel):
    """Disease hotspot information"""
    location: str  # e.g., "top-left", "center", "bottom-right"
    severity_level: float  # 0-1 scale
    pixel_coverage: float  # Percentage of affected area


class AffectedRegion(BaseModel):
    """Affected region analysis"""
    total_infected_area: float  # Percentage
    primary_hotspot: DiseaseHotspot
    secondary_hotspots: list = []
    infection_pattern: str  # "localized", "scattered", "widespread"
    urgency: str  # "Low", "Medium", "High", "Critical"


class PlantInfo(BaseModel):
    """Plant information model"""
    name: str
    is_healthy: bool


class PredictionResponse(BaseModel):
    """API response model for plant disease predictions"""
    disease: str
    confidence: float
    heatmap_url: str
    plant_info: PlantInfo
    recommendations: Recommendation
    affected_regions: AffectedRegion
    prevalence: PrevalenceInfo = None
    heatmap_base64: str = None  # Optional: base64 encoded image


# ─── Helper Functions ──────────────────
def clean_disease_label(label: str) -> str:
    """Clean disease label by replacing underscores with spaces"""
    return label.replace("__", " ").replace("_", " ")


def get_recommendations(disease_label: str) -> dict:
    """Get AI recommendations for a disease"""
    # Try exact match first
    if disease_label in RECOMMENDATIONS_DB:
        return RECOMMENDATIONS_DB[disease_label]
    
    # Try matching with class key format
    for key, value in RECOMMENDATIONS_DB.items():
        if clean_disease_label(key).lower() == disease_label.lower():
            return value
    
    # Default recommendation
    return {
        "severity": "Unknown",
        "treatment": [
            "Consult local agricultural extension office",
            "Quarantine the plant",
            "Remove infected parts"
        ],
        "prevention": [
            "Maintain plant hygiene",
            "Ensure proper spacing",
            "Avoid overhead watering"
        ],
        "products": ["Consult local expert"]
    }


def get_plant_info(class_key: str) -> dict:
    """Extract plant information from class_info"""
    if class_key in class_info:
        info = class_info[class_key]
        plant_name = clean_disease_label(info.get("plant", "Unknown"))
        is_healthy = info.get("is_healthy", False)
        return {
            "name": plant_name,
            "is_healthy": is_healthy
        }
    return {"name": "Unknown", "is_healthy": False}


def get_prevalence(disease_class_key: str, region: str = "Tunisia") -> dict:
    """Get disease prevalence information for a specific region"""
    # Clean disease key for lookup
    disease_key = disease_class_key
    
    if disease_key in PREVALENCE_DB:
        regions_data = PREVALENCE_DB[disease_key]
        
        # Return specific region or default to Tunisia
        if region in regions_data:
            return regions_data[region]
        elif "Tunisia" in regions_data:
            return regions_data["Tunisia"]
    
    # Default prevalence if disease not found
    return {
        "prevalence_rate": 50,
        "season": "Year-round",
        "risk_level": "Medium"
    }


def detect_disease_hotspots(cam: np.ndarray) -> dict:
    """Detect hotspots (most affected regions) in the CAM heatmap"""
    h, w = cam.shape
    grid_size = 3  # Divide into 3x3 grid
    cell_h, cell_w = h // grid_size, w // grid_size
    
    # Grid positions
    positions = [
        "top-left", "top-center", "top-right",
        "mid-left", "center", "mid-right",
        "bottom-left", "bottom-center", "bottom-right"
    ]
    
    # Calculate average intensity for each grid cell
    grid_values = []
    for i in range(grid_size):
        for j in range(grid_size):
            y_start, y_end = i * cell_h, (i + 1) * cell_h
            x_start, x_end = j * cell_w, (j + 1) * cell_w
            avg_value = np.mean(cam[y_start:y_end, x_start:x_end])
            grid_values.append((positions[i * grid_size + j], avg_value))
    
    # Sort by intensity (highest first)
    grid_values.sort(key=lambda x: x[1], reverse=True)
    
    # Calculate total infected area
    total_infected = np.sum(cam > 0.3) / (h * w) * 100
    
    # Determine infection pattern
    top_3_intensity = np.mean([v[1] for v in grid_values[:3]])
    if total_infected < 10:
        pattern = "localized"
    elif total_infected < 40:
        pattern = "scattered"
    else:
        pattern = "widespread"
    
    # Determine urgency
    if total_infected > 60:
        urgency = "Critical"
    elif total_infected > 40:
        urgency = "High"
    elif total_infected > 20:
        urgency = "Medium"
    else:
        urgency = "Low"
    
    # Primary hotspot
    primary_location, primary_severity = grid_values[0]
    primary_hotspot = {
        "location": primary_location,
        "severity_level": float(primary_severity),
        "pixel_coverage": float(primary_severity * 100)
    }
    
    # Secondary hotspots
    secondary_hotspots = []
    for location, severity in grid_values[1:4]:
        if severity > 0.2:  # Only include significant hotspots
            secondary_hotspots.append({
                "location": location,
                "severity_level": float(severity),
                "pixel_coverage": float(severity * 100)
            })
    
    return {
        "total_infected_area": float(total_infected),
        "primary_hotspot": primary_hotspot,
        "secondary_hotspots": secondary_hotspots,
        "infection_pattern": pattern,
        "urgency": urgency
    }


# ─── Preprocess ────────────────────
def preprocess(image):
    image = image.resize((224, 224))
    img = np.array(image).astype(np.float32) / 255.0

    mean = np.array([0.485, 0.456, 0.406])
    std = np.array([0.229, 0.224, 0.225])

    img = (img - mean) / std
    img = np.transpose(img, (2, 0, 1))
    img = np.expand_dims(img, axis=0)

    return torch.tensor(img, dtype=torch.float32)


# ─── Grad-CAM ──────────────────────
def generate_gradcam(model, input_tensor, class_idx):
    """Generate Grad-CAM visualization with robust error handling"""
    try:
        gradients = []
        activations = []

        def backward_hook(module, grad_in, grad_out):
            if grad_out[0] is not None:
                gradients.append(grad_out[0].detach())

        def forward_hook(module, input, output):
            activations.append(output.detach())

        # Find the last convolutional layer
        conv_layer = None
        for module in model.modules():
            if isinstance(module, torch.nn.Conv2d):
                conv_layer = module

        if conv_layer is None:
            # Fallback: return uniform heatmap
            return np.ones((224, 224), dtype=np.float32) * 0.5

        conv_layer.register_forward_hook(forward_hook)
        conv_layer.register_backward_hook(backward_hook)

        # Forward pass
        input_tensor = input_tensor.requires_grad_(True)
        output = model(input_tensor)
        loss = output[0, class_idx]

        # Backward pass
        model.zero_grad()
        loss.backward()

        # Extract gradients and activations
        if not gradients or not activations:
            return np.ones((224, 224), dtype=np.float32) * 0.5

        grads = gradients[0].cpu().numpy()
        acts = activations[0].cpu().numpy()

        # Handle batch dimension
        if grads.ndim == 4:  # (batch, channels, height, width)
            grads = grads[0]
        if acts.ndim == 4:  # (batch, channels, height, width)
            acts = acts[0]

        # Ensure we have proper channel/spatial dimensions
        if grads.ndim != 3 or acts.ndim != 3:
            return np.ones((224, 224), dtype=np.float32) * 0.5

        # Compute weights: average gradient over spatial dims
        weights = np.mean(grads, axis=(1, 2))  # Shape: (channels,)

        # Generate CAM
        cam = np.zeros(acts.shape[1:], dtype=np.float32)
        for i, w in enumerate(weights):
            cam += w * acts[i]

        # Normalize
        cam = np.maximum(cam, 0)
        cam = cv2.resize(cam, (224, 224))
        cam = cam - cam.min()
        cam = cam / (cam.max() + 1e-8)

        return cam

    except Exception as e:
        print(f"GradCAM error: {e}")
        return np.ones((224, 224), dtype=np.float32) * 0.5


# ─── Endpoints ────────────────────────
@app.post("/predict", response_model=PredictionResponse)
async def predict(file: UploadFile = File(...), region: str = "Tunisia", include_base64: bool = False):
    """Predict plant disease from image and return heatmap URL"""
    contents = await file.read()
    image = Image.open(io.BytesIO(contents)).convert("RGB")

    input_tensor = preprocess(image)

    # Prediction
    with torch.no_grad():
        outputs = model(input_tensor)
        probs = F.softmax(outputs, dim=1).numpy()[0]

    pred_idx = int(np.argmax(probs))
    confidence = float(np.max(probs))

    # Grad-CAM
    cam = generate_gradcam(model, input_tensor, pred_idx)

    # Overlay heatmap
    img_np = np.array(image.resize((224, 224)))
    heatmap = cv2.applyColorMap(np.uint8(255 * cam), cv2.COLORMAP_JET)
    overlay = cv2.addWeighted(img_np, 0.6, heatmap, 0.4, 0)

    # Save image
    output_path = "outputs/result.jpg"
    cv2.imwrite(output_path, overlay)

    # Get clean disease label
    class_key = idx_to_class[pred_idx]
    disease_label = clean_disease_label(class_key)
    
    # Get plant information
    plant_info = get_plant_info(class_key)
    
    # Get AI recommendations
    recommendations = get_recommendations(class_key)
    
    # Get disease prevalence for region
    prevalence = get_prevalence(class_key, region)
    
    # Detect disease hotspots and affected regions
    affected_regions = detect_disease_hotspots(cam)

    # Prepare response
    response = {
        "disease": disease_label,
        "confidence": round(confidence, 4),
        "heatmap_url": f"/static/result.jpg",
        "plant_info": plant_info,
        "recommendations": recommendations,
        "affected_regions": affected_regions,
        "prevalence": prevalence
    }

    # Optional: Include base64 encoded image for mobile apps
    if include_base64:
        with open(output_path, "rb") as img_file:
            encoded = base64.b64encode(img_file.read()).decode("utf-8")
            response["heatmap_base64"] = encoded

    return response


@app.get("/")
async def root():
    """API documentation"""
    return {
        "name": "Plant Disease Classification API",
        "version": "1.0",
        "endpoints": {
            "POST /predict": "Predict disease from image",
            "GET /docs": "Interactive API documentation (Swagger)",
            "GET /regions": "Get available regions and prevalence data",
            "GET /static/{file}": "Serve generated heatmap images"
        },
        "usage": "POST /predict with multipart/form-data (file parameter)",
        "parameters": {
            "file": "Image file (jpg, png, etc.)",
            "region": "Region for prevalence data (default: Tunisia)",
            "include_base64": "Optional: true/false to include base64 encoded image"
        }
    }


@app.get("/regions")
async def get_available_regions():
    """Get available regions and disease prevalence data"""
    regions = set()
    for disease, region_data in PREVALENCE_DB.items():
        regions.update(region_data.keys())
    
    return {
        "available_regions": sorted(list(regions)),
        "diseases": list(PREVALENCE_DB.keys()),
        "prevalence_data": PREVALENCE_DB,
        "usage": "Use ?region=RegionName parameter in /predict endpoint"
    }