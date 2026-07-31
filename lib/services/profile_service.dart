import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// NOTE : ni GET /v1/client/profile ni PUT/PATCH de mise à jour du profil
/// n'existent côté Laravel (absents de routes/api.php au moment où cet écran
/// a été créé). Cet appel est prêt à fonctionner dès que l'endpoint existera ;
/// en attendant, un 404 est traduit en message explicite plutôt que
/// d'inventer une fausse réussite qui ne persisterait rien réellement.
class ProfileService {
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
      return {'success': false, 'message': data['message'] ?? 'Impossible de mettre à jour le profil.'};
    } catch (e) {
      return {
        'success': false,
        'code': 'NETWORK_ERROR',
        'message': 'Impossible de contacter le serveur.',
      };
    }
  }
}
