import os
import pandas as pd
import joblib

from sklearn.model_selection import train_test_split
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, LabelEncoder

from xgboost import XGBClassifier

BASE_DIR = os.path.dirname(__file__)
DATA_PATH = os.path.join(BASE_DIR, "agri_dataset_50000.csv")
MODEL_PATH = os.path.join(BASE_DIR, "model.pkl")
ENCODER_PATH = os.path.join(BASE_DIR, "label_encoder.pkl")

# Load dataset
if not os.path.exists(DATA_PATH):
    raise FileNotFoundError(f"Dataset not found at {DATA_PATH}")

df = pd.read_csv(DATA_PATH)

# Features
X = df.drop("water_need", axis=1)

# Encode target
label_encoder = LabelEncoder()
y = label_encoder.fit_transform(df["water_need"])

# Columns
cat_cols = ["plant", "stage"]
num_cols = ["temp", "humidity", "rain", "soil_moisture", "age_day"]

# Preprocessing
preprocessor = ColumnTransformer([
    ("cat", OneHotEncoder(handle_unknown="ignore"), cat_cols),
    ("num", "passthrough", num_cols)
])

# Model
model = XGBClassifier(
    n_estimators=300,
    max_depth=6,
    learning_rate=0.05,
    subsample=0.8,
    colsample_bytree=0.8,
    eval_metric="mlogloss"
)

# Pipeline
pipeline = Pipeline([
    ("preprocessor", preprocessor),
    ("model", model)
])

# Split
X_train, X_test, y_train, y_test = train_test_split(
    X,
    y,
    test_size=0.2,
    random_state=42
)

# Train
pipeline.fit(X_train, y_train)

# Accuracy
score = pipeline.score(X_test, y_test)
print("Accuracy:", score)

# Save model + encoder
joblib.dump(pipeline, MODEL_PATH)
joblib.dump(label_encoder, ENCODER_PATH)

print(f"Model saved to {MODEL_PATH}")
print(f"Encoder saved to {ENCODER_PATH}")