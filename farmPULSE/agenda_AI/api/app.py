from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import datetime, timedelta
import requests
import numpy as np
import os
import sys
from dotenv import load_dotenv

# Charger les variables d'environnement
load_dotenv()

# =========================
# CONFIGURATION
# =========================
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.append(ROOT_DIR)

from model.predict import predict_water

app = FastAPI()

# Récupérer la clé API depuis .env
API_KEY = os.getenv("OPENWEATHER_API_KEY")

# =========================
# INPUT MODELS
# =========================
class PlantInput(BaseModel):
    plant_type: str
    planting_date: str
    city: str

# =========================
# PLANTS DATA
# =========================
PLANTS = {
    "tomate": 60,
    "pomme de terre": 90,
    "poivron": 70,
    "olive": 180,
    "laitue": 45
}

# =========================
# HELPERS
# =========================
def get_weather(city):
    if not API_KEY:
        # Fallback pour test si pas de clé API
        return {"temperature": 25, "humidity": 50, "rain": 0}
        
    url = f"http://api.openweathermap.org/data/2.5/weather?q={city}&appid={API_KEY}&units=metric"
    res = requests.get(url)
    if res.status_code != 200:
        raise HTTPException(400, f"Erreur météo: {res.text}")
    
    data = res.json()
    return {
        "temperature": data["main"]["temp"],
        "humidity": data["main"]["humidity"],
        "rain": data.get("rain", {}).get("1h", 0)
    }

def get_stage(age):
    if age <= 10: return "Germination"
    elif age <= 30: return "Végétative"
    elif age <= 60: return "Floraison"
    return "Fructification / Maturité"

def get_irrigation_details(water_need):
    if water_need == "high":
        return {"qty": "4-5 Litres", "freq": "2x / jour"}
    if water_need == "medium":
        return {"qty": "2-3 Litres", "freq": "1x / jour"}
    return {"qty": "1-2 Litres", "freq": "Tous les 2 jours"}

# =========================
# MAIN API
# =========================
@app.post("/agenda")
def agenda(data: PlantInput):
    try:
        plant_name = data.plant_type.lower()
        
        # Trouver la plante même si le nom est partiel
        matched_key = None
        for k in PLANTS.keys():
            if k in plant_name:
                matched_key = k
                break
        
        cycle_days = PLANTS.get(matched_key, 60)

        # 1. Météo
        weather = get_weather(data.city)

        # 2. Dates
        planting_date = datetime.strptime(data.planting_date, "%Y-%m-%d")
        today = datetime.now()
        age_days = (today - planting_date).days
        harvest_date = planting_date + timedelta(days=cycle_days)
        remaining_days = (harvest_date - today).days

        # 3. ML Prediction
        prediction = predict_water({
            "plant": matched_key or "tomato",
            "temp": weather["temperature"],
            "humidity": weather["humidity"],
            "rain": weather["rain"],
            "soil_moisture": 40,
            "age_day": max(0, age_days),
            "stage": get_stage(age_days).lower()
        })

        if isinstance(prediction, np.integer):
            prediction = int(prediction)

        labels = {0: "low", 1: "medium", 2: "high"}
        water_need = labels.get(prediction, "medium")

        return {
            "status": "success",
            "plant": plant_name,
            "weather": weather,
            "age_days": max(0, age_days),
            "stage": get_stage(age_days),
            "water_need": water_need,
            "irrigation": get_irrigation_details(water_need),
            "harvest_date": harvest_date.strftime("%d %B %Y"),
            "remaining_days": max(0, remaining_days)
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(500, detail=str(e))
