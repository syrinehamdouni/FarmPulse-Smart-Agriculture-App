import os
import joblib
import pandas as pd

BASE_DIR = os.path.dirname(__file__)
MODEL_PATH = os.path.join(BASE_DIR, "model.pkl")

if not os.path.exists(MODEL_PATH):
    raise FileNotFoundError(
        f"Model file not found at {MODEL_PATH}. Run training first."
    )

model = joblib.load(MODEL_PATH)


# =========================
# PREDICTION FUNCTION
# =========================
def predict_water(data: dict):
    """
    Predict water need using ML model
    """

    df = pd.DataFrame([data])

    prediction = model.predict(df)

    return prediction[0]