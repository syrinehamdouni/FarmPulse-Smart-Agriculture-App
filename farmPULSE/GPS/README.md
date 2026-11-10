# 🌱 FarmPULSE GPS Crop Recommender

نظام توصية محاصيل متكامل يجمع بين:
- 📍 إحداثيات GPS
- 🌦️ بيانات الطقس الحية من OpenWeatherMap
- 🧬 نموذج ML مدرب على بيانات المزارع الحقيقية
- 💧 توصيات الري والتنبيهات

## 📋 المتطلبات

```bash
pip install requests pandas scikit-learn joblib matplotlib
```

## 🔑 إعداد OpenWeatherMap API

1. احصل على مفتاح مجاني من https://openweathermap.org/api
2. ضع المفتاح في متغير بيئي:
   ```powershell
   setx OPENWEATHER_API_KEY "YOUR_API_KEY"
   ```

## 🚀 التشغيل

### 1️⃣ نموذج بسيط (قواعد ثابتة)
```bash
python gps_crop_recommender.py --lat 36.8 --lon 10.1 --soil clay --api-key YOUR_API_KEY
```

### 2️⃣ اختبار مع بيانات محاكاة
```bash
python test_recommender.py
```

### 3️⃣ نموذج متقدم (ML + GPS + الطقس)
أولاً: دريب النموذج
```bash
jupyter notebook train_model.ipynb
```

ثم: استخدم النموذج المدرب
```python
from integrated_recommender import FarmPULSERecommender

recommender = FarmPULSERecommender()
result = recommender.recommend(
    lat=36.8, lon=10.1, 
    soil="clay", climate="humid", 
    location="sfax",
    api_key="YOUR_API_KEY"
)
print(result)
```

## 📊 البيانات

- `FarmPulse_data.csv`: 20+ ميزة تشمل الطقس والتربة والمحاصيل
- `train_model.ipynb`: تدريب Random Forest على البيانات
- `integrated_recommender.py`: نموذج متكامل يجمع كل شيء

## 🎯 ما يفعله البرنامج

### النموذج البسيط:
1. يجلب الطقس الحالي من OpenWeatherMap
2. يطبق قواعس منطقية على درجة الحرارة والرطوبة
3. يقترح محصول مناسب
4. يعطي خطة ري
5. يعرض تنبيهات (صقيع، أمراض فطرية، إلخ)

### النموذج المتقدم:
1. يحمل نموذج ML مدرب
2. يجلب بيانات الطقس الحية
3. يعدّ الميزات (جودة التربة، المناخ، إلخ)
4. يتنبأ بالمحصول الأمثل مع درجة ثقة
5. يعطي توصيات مخصصة
