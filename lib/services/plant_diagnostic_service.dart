import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class PlantDiagnosticResult {
  final String disease;
  final double confidence;
  final String heatmapUrl;
  final String plantName;
  final bool isHealthy;
  final String severity;
  final List<dynamic> treatment;
  final List<dynamic> prevention;
  final List<dynamic> products;
  final double infectedArea;
  final String infectionPattern;
  final String urgency;
  final double prevalenceRate;
  final String season;
  final String riskLevel;
  final String? heatmapBase64;

  PlantDiagnosticResult({
    required this.disease,
    required this.confidence,
    required this.heatmapUrl,
    required this.plantName,
    required this.isHealthy,
    required this.severity,
    required this.treatment,
    required this.prevention,
    required this.products,
    required this.infectedArea,
    required this.infectionPattern,
    required this.urgency,
    required this.prevalenceRate,
    required this.season,
    required this.riskLevel,
    this.heatmapBase64,
  });

  factory PlantDiagnosticResult.fromJson(Map<String, dynamic> json) {
    return PlantDiagnosticResult(
      disease: json['disease'] ?? '',
      confidence: ((json['confidence'] ?? 0) * 100).toDouble(),
      heatmapUrl: json['heatmap_url'] ?? '',
      plantName: json['plant_info']?['name'] ?? '',
      isHealthy: json['plant_info']?['is_healthy'] ?? false,
      severity: json['recommendations']?['severity'] ?? '',
      treatment: json['recommendations']?['treatment'] ?? [],
      prevention: json['recommendations']?['prevention'] ?? [],
      products: json['recommendations']?['products'] ?? [],
      infectedArea: (json['affected_regions']?['total_infected_area'] ?? 0).toDouble(),
      infectionPattern: json['affected_regions']?['infection_pattern'] ?? '',
      urgency: json['affected_regions']?['urgency'] ?? '',
      prevalenceRate: (json['prevalence']?['prevalence_rate'] ?? 0).toDouble(),
      season: json['prevalence']?['season'] ?? '',
      riskLevel: json['prevalence']?['risk_level'] ?? '',
      heatmapBase64: json['heatmap_base64'],
    );
  }
}

class PlantDiagnosticService {
  static const String baseUrl = ApiConfig.diseaseApi;

  static Future<PlantDiagnosticResult> diagnosePlant({
    required String imagePath,
    String region = "Tunisia",
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/predict?region=$region&include_base64=true"),
      );
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PlantDiagnosticResult.fromJson(data);
      } else {
        throw Exception("Erreur API : ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Erreur connexion API : $e");
    }
  }
}
