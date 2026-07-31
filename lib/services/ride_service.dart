import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// NOTE : L'endpoint POST /v1/client/rides n'existe pas encore côté Laravel
/// (absent de routes/api.php au 2026-07-31). Cet appel est prêt à fonctionner
/// dès qu'il sera créé côté backend ; en attendant, un 404 est traduit en
/// message explicite plutôt que d'inventer une fausse réponse de succès.
class RideService {
  static Future<Map<String, dynamic>> requestRide(
    String jwtToken, {
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double destLat,
    required double destLng,
    required String destAddress,
    required String serviceType,
    required String paymentMethod,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/client/rides'),
        headers: ApiConfig.authHeaders(jwtToken),
        body: jsonEncode({
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'pickup_address': pickupAddress,
          'destination_lat': destLat,
          'destination_lng': destLng,
          'destination_address': destAddress,
          'service_type': serviceType,
          'payment_method': paymentMethod,
        }),
      );

      if (response.statusCode == 404) {
        return {
          'success': false,
          'code': 'ENDPOINT_MISSING',
          'message':
              "Endpoint manquant côté Laravel : POST /v1/client/rides n'existe pas encore dans routes/api.php. À créer côté backend avant de pouvoir commander une course.",
        };
      }

      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
        return {'success': true, 'ride': data['data']};
      }
      return {'success': false, 'message': data['message'] ?? 'Impossible de créer la course.'};
    } catch (e) {
      return {
        'success': false,
        'code': 'NETWORK_ERROR',
        'message': 'Impossible de contacter le serveur.',
      };
    }
  }
}
