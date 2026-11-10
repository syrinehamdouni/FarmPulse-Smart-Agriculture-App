from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pandas as pd
import numpy as np
import joblib

app = FastAPI(title="FarmPulse AI API", version="FINAL")

# =========================
# LOAD MODELS
# =========================
model = joblib.load("rf_model.pkl")
scaler = joblib.load("scaler.pkl")
encoders = joblib.load("encoders.pkl")
kmeans = joblib.load("kmeans.pkl")
scaler_cl = joblib.load("scaler_cluster.pkl")
iso = joblib.load("isoforest.pkl")

# =========================
# FEATURES
# =========================
FEATURES = [
    "Farm_Size (ha)","Crop_Type","Soil_pH","Moisture",
    "Nitrogen","Phosphorus","Potassium","Total_Precipitations",
    "Temp_Amplitude","Input_Needs","Location","Climate_Condition",
    "Soil_Type","Drought_Risk","Soil_pH_Category",
    "Soil_Health","Climate_Stress","Fertilizer_Needs"
]

CLUSTER_FEATURES = [
    "Crop_Type",
    "Farm_Size (ha)",
    "Fertilizer_Needs",
    "Nitrogen",
    "Phosphorus",
    "Potassium"
]

CAT_COLS = list(encoders.keys())

# =========================
# INPUT MODEL
# =========================
class Input(BaseModel):
    Farm_Size: float
    Crop_Type: str
    Soil_pH: float
    Moisture: float
    Nitrogen: float
    Phosphorus: float
    Potassium: float
    Total_Precipitations: float
    Temp_Amplitude: float
    Input_Needs: str
    Location: str
    Climate_Condition: str
    Soil_Type: str
    Drought_Risk: str

# =========================
# SAFE CLEAN FUNCTION
# =========================
def clean(x):
    if isinstance(x, (np.bool_, bool)):
        return bool(x)
    if isinstance(x, (np.integer,)):
        return int(x)
    if isinstance(x, (np.floating,)):
        return float(x)
    return x

# =========================
# SAFE ENCODING
# =========================
def encode(col, val):
    try:
        val = str(val)
        if col in encoders:
            le = encoders[col]
            if val not in le.classes_:
                val = le.classes_[0]
            return le.transform([val])[0]
        return val
    except:
        return 0

# =========================
# BUILD DATAFRAME
# =========================
def build(data: Input):

    row = {
        "Farm_Size (ha)": data.Farm_Size,
        "Crop_Type": data.Crop_Type,
        "Soil_pH": data.Soil_pH,
        "Moisture": data.Moisture,
        "Nitrogen": data.Nitrogen,
        "Phosphorus": data.Phosphorus,
        "Potassium": data.Potassium,
        "Total_Precipitations": data.Total_Precipitations,
        "Temp_Amplitude": data.Temp_Amplitude,
        "Input_Needs": data.Input_Needs,
        "Location": data.Location,
        "Climate_Condition": data.Climate_Condition,
        "Soil_Type": data.Soil_Type,
        "Drought_Risk": data.Drought_Risk,
        "Soil_pH_Category": "Neutral",
        "Soil_Health": "Good",
        "Climate_Stress": "Low",
        "Fertilizer_Needs": "Medium Need"
    }

    df = pd.DataFrame([row])

    for col in df.columns:
        if col in encoders:
            df[col] = df[col].astype(str).apply(lambda x: encode(col, x))

    return df

# =========================
# MAIN API
# =========================
@app.post("/predict")
def predict(data: Input):

    try:
        df = build(data)

        # SCALE & PREDICT (REGRESSION)
        X = scaler.transform(df[FEATURES])
        pred = float(model.predict(X)[0])

        # ANOMALY
        anomaly = bool(iso.predict(X)[0] == -1)

        # CLUSTER FIX
        try:
            Xc = df[CLUSTER_FEATURES]
            Xc_scaled = scaler_cl.transform(Xc)
            cluster = int(kmeans.predict(Xc_scaled)[0])
        except Exception as e:
            print(f"Cluster Error: {e}")
            cluster = -1

        # DYNAMIC SCORES & RECOMMENDATIONS FOR FLUTTER
        soil_score = int(min(100, max(20, (data.Soil_pH / 7.5) * 90)))
        productivity_score = int(min(100, (pred / 12.0) * 100))
        
        recs = []
        if anomaly:
            recs.append("⚠️ Données atypiques détectées. Vérifiez vos capteurs.")
        
        if cluster == 0:
            recs.append("✅ Excellente gestion. Continuez votre programme actuel.")
        elif cluster == 1:
            recs.append("🧪 Carence nutritionnelle possible. Un apport d'azote est conseillé.")
        else:
            recs.append("💧 Stress hydrique détecté. Optimisez l'irrigation.")
            
        if data.Soil_pH < 6.0:
            recs.append("📉 Sol acide: Prévoyez un amendement calcaire.")

        # RESPONSE SAFE
        return {
            "predicted_yield": clean(round(pred, 2)),
            "unit": "tons/hectare",
            "anomaly": clean(anomaly),
            "cluster": clean(cluster),
            "soil_score": soil_score,
            "productivity_score": productivity_score,
            "recommendations": recs,
            "status": "success"
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# =========================
# RUN
# =========================
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("farmpulse_api:app", host="0.0.0.0", port=5001, reload=True)
