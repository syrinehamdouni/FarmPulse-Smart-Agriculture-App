import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class AgendaService {
  static const String baseUrl = ApiConfig.agendaApi;

  static Future<Map<String, dynamic>> getAgenda({
    required String plantType,
    required String plantingDate,
    required String city,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/agenda'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "plant_type": plantType,
          "planting_date": plantingDate,
          "city": city,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to load agenda: ${response.body}");
      }
    } catch (e) {
      throw Exception("Erreur connexion Agenda API : $e");
    }
  }
}
