
class ApiConfig {
  static const String gpsApi = "http://192.168.1.127:5000";
  static const String cropApi = "http://192.168.1.127:5001";
  static const String agendaApi = "http://192.168.1.127:8000";
  static const String diseaseApi = "http://192.168.1.127:5002";

  static const String groqApiKey =
      String.fromEnvironment('GROQ_API_KEY');
}

