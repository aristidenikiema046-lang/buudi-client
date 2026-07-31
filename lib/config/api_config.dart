import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  ApiConfig._();

  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.79.185.64:8000/api';

  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  static Map<String, String> authHeaders(String jwtToken) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $jwtToken',
      };
}
