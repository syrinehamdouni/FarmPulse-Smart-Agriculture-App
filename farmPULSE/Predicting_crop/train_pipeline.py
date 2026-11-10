import pandas as pd
import numpy as np
import joblib
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.ensemble import RandomForestRegressor, IsolationForest
from sklearn.cluster import KMeans

# =========================
# LOAD DATA
# =========================
df = pd.read_csv("FarmPulse_data.csv")
df.columns = df.columns.str.strip()

TARGET = "Yield_Per_Hectare (tons)"

CAT_COLS = [
    "Crop_Type","Input_Needs","Location","Climate_Condition",
    "Soil_Type","Drought_Risk","Soil_pH_Category",
    "Soil_Health","Climate_Stress","Fertilizer_Needs"
]

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

# =========================
# ENCODERS
# =========================
encoders = {}
df_enc = df.copy()

for col in CAT_COLS:
    le = LabelEncoder()
    df_enc[col] = le.fit_transform(df[col].astype(str))
    encoders[col] = le

X = df_enc[FEATURES]
y = df_enc[TARGET]

scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# =========================
# MODEL
# =========================
X_train, X_test, y_train, y_test = train_test_split(
    X_scaled, y, test_size=0.2, random_state=42
)

model = RandomForestRegressor(n_estimators=150, random_state=42)
model.fit(X_train, y_train)

# =========================
# CLUSTER + ANOMALY
# =========================
# FIX: KMeans must be trained on the SAME features used in API
scaler_cl = StandardScaler()
Xc_scaled = scaler_cl.fit_transform(df_enc[CLUSTER_FEATURES])

kmeans = KMeans(n_clusters=3, random_state=42)
kmeans.fit(Xc_scaled)

iso = IsolationForest(contamination=0.05, random_state=42)
iso.fit(X_scaled)

# =========================
# SAVE ARTIFACTS
# =========================
joblib.dump(model, "rf_model.pkl")
joblib.dump(scaler, "scaler.pkl")
joblib.dump(encoders, "encoders.pkl")
joblib.dump(kmeans, "kmeans.pkl")
joblib.dump(scaler_cl, "scaler_cluster.pkl")
joblib.dump(iso, "isoforest.pkl")

print("✅ TRAINING DONE")
