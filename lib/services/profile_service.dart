import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/api_error.dart';

class ProfileService {
  /// GET /v1/client/profile — utilisé pour restaurer la session au démarrage
  /// (voir AuthBloc._onAppStarted) et pour rafraîchir l'écran Profil.
  static Future<Map<String, dynamic>> getProfile(String jwtToken) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/client/profile'),
        headers: ApiConfig.authHeaders(jwtToken),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'message': apiErrorMessage(data, 'Impossible de charger le profil.')};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    String jwtToken, {
    required String name,
    String? email,
    String? phone,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/v1/client/profile'),
        headers: ApiConfig.authHeaders(jwtToken),
        body: jsonEncode({
          'name': name,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
        }),
      );

      if (response.statusCode == 404) {
        return {
          'success': false,
          'code': 'ENDPOINT_MISSING',
          'message':
              "Endpoint manquant côté Laravel : PUT /v1/client/profile n'existe pas encore dans routes/api.php. À créer côté backend avant de pouvoir enregistrer ces modifications.",
        };
      }

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'user': data['data'] ?? data['user']};
      }
      return {'success': false, 'message': apiErrorMessage(data, 'Impossible de mettre à jour le profil.')};
    } catch (e) {
      return {
        'success': false,
        'code': 'NETWORK_ERROR',
        'message': 'Impossible de contacter le serveur.',
      };
    }
  }
}
