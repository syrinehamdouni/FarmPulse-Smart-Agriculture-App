import requests

url = "http://127.0.0.1:5000/predict"

data = {
    "Farm_Size (ha)": 5,
    "Location": "Tunis",
    "Climate_Condition": "Sunny",
    "Soil_Type": "Loamy",
    "Soil_pH": 6.5,
    "Moisture": 40,
    "Nitrogen": 30,
    "Phosphorus": 20,
    "Potassium": 15,
    "Total_Precipitations": 200,
    "Temp_Amplitude": 10,
    "Drought_Risk": "Low",
    "Soil_pH_Category": "Neutral",
    "Soil_Health": "Good",
    "Climate_Stress": "Low",
    "Fertilizer_Needs": "Medium",
    "Crop_Type": "Wheat"
}

res = requests.post(url, json=data)

print(res.json())