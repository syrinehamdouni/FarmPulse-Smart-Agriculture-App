from flask import Flask, request, jsonify
import joblib
import os
import requests
import pandas as pd

app = Flask(__name__)

# ───────── Attempt to load models ─────────
MODELS_LOADED = False
crop_model = None
yield_model = None
scaler = None
encoders = None

try:
    # Check for file existence before loading
    if all(os.path.exists(f) for f in ["crop_model.pkl", "yield_model.pkl", "scaler.pkl", "encoders.pkl"]):
        crop_model = joblib.load("crop_model.pkl")
        yield_model = joblib.load("yield_model.pkl")
        scaler = joblib.load("scaler.pkl")
        encoders = joblib.load("encoders.pkl")
        MODELS_LOADED = True
        print("✅ Models Loaded Successfully")
    else:
        print("⚠️ Models missing - Running in MOCK MODE for UI testing")
except Exception as e:
    print(f"❌ Error loading models: {e}")

@app.route("/predict", methods=["POST"])
def predict():
    try:
        data = request.json or {}
        # Ensure lat/lng are floats and have defaults
        try:
            lat = float(data.get("lat", 36.8))
            lng = float(data.get("lng", 10.1))
        except (ValueError, TypeError):
            lat, lng = 36.8, 10.1

        # Logic for selection (Mock or Real)
        if MODELS_LOADED:
            # Placeholder for real prediction logic if needed later
            # For now, we still provide a stable response structure
            pass

        # Robust Response Structure (Ensures Flutter UI always has data)
        crop = "Blé Dur" if lat > 34 else "Oliviers"
        
        response = {
            "status": "success",
            "recommended_crop": crop,
            "confidence": 0.92,
            "alternative_crops": ["Orge", "Maïs", "Tomate"],
            "expected_yield": {
                "min": 4.1,
                "max": 5.9
            },
            "risk_level": "Faible" if lat > 33 else "Moyen",
            "recommendation_reason": f"Zone GPS {lat:.2f}, conditions adaptées pour {crop}",
            "recommendations": [
                "Optimiser l'irrigation selon l'humidité locale",
                "Surveiller le stress climatique saisonnier",
                "Appliquer une fertilisation équilibrée"
            ],
            "scores": {
                "soil": 82,
                "yield": 88
            },
            "location": {
                "lat": lat,
                "lng": lng
            }
        }

        return jsonify(response)

    except Exception as e:
        print(f"Error in /predict: {e}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
