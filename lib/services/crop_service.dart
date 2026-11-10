import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class CropPredictionResult {
  final double predictedYield;
  final String unit;
  final bool anomaly;
  final int cluster;
  final int soilScore;
  final int productivityScore;
  final List<String> recommendations;

  CropPredictionResult({
    required this.predictedYield,
    required this.unit,
    required this.anomaly,
    required this.cluster,
    required this.soilScore,
    required this.productivityScore,
    required this.recommendations,
  });

  factory CropPredictionResult.fromJson(Map<String, dynamic> json) {
    return CropPredictionResult(
      predictedYield: (json['predicted_yield'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      anomaly: json['anomaly'] ?? false,
      cluster: json['cluster'] ?? 0,
      soilScore: json['soil_score'] ?? 0,
      productivityScore: json['productivity_score'] ?? 0,
      recommendations: List<String>.from(json['recommendations'] ?? []),
    );
  }
}

class CropService {
  static const String baseUrl = ApiConfig.cropApi;

  static Future<CropPredictionResult> predictYield({
    required double farmSize,
    required String cropType,
    required double soilPH,
    required double moisture,
    required double nitrogen,
    required double phosphorus,
    required double potassium,
    required double precipitation,
    required double tempAmplitude,
    required String inputNeeds,
    required String location,
    required String climateCondition,
    required String soilType,
    required String droughtRisk,
  }) async {
    final Map<String, dynamic> body = {
      "Farm_Size": farmSize,
      "Crop_Type": cropType,
      "Soil_pH": soilPH,
      "Moisture": moisture,
      "Nitrogen": nitrogen,
      "Phosphorus": phosphorus,
      "Potassium": potassium,
      "Total_Precipitations": precipitation,
      "Temp_Amplitude": tempAmplitude,
      "Input_Needs": inputNeeds,
      "Location": location,
      "Climate_Condition": climateCondition,
      "Soil_Type": soilType,
      "Drought_Risk": droughtRisk,
      // Note: Extra calculated fields removed as they are handled by the API internally
    };

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/predict"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CropPredictionResult.fromJson(data);
      } else {
        throw Exception(
          "Erreur API: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      throw Exception("Erreur connexion API : $e");
    }
  }
}
