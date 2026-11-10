import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class GpsAiService {
  static const String baseUrl = ApiConfig.gpsApi;

  static Future<Map<String, dynamic>> predictCrop({
    required double lat,
    required double lng,
  }) async {

    final url = Uri.parse("$baseUrl/predict");

    final body = {
      "lat": lat,
      "lng": lng
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("GPS API Error: ${response.body}");
    }
  }
}