import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/ride_draft.dart';
import '../utils/api_error.dart';

class RideService {
  /// Convertit le moyen de paiement interne Flutter ('card', 'cash', ...)
  /// vers les valeurs exactes attendues par le validator Laravel
  /// (wallet|mobile_money|carte|especes).
  static String _backendPaymentMethod(String method) {
    switch (method) {
      case 'card':
        return 'carte';
      case 'cash':
        return 'especes';
      default:
        return method; // wallet, mobile_money : identiques des deux côtés
    }
  }

  /// Convertit le type de service interne ('ok_taxi', ...) vers le libellé
  /// exact attendu par le validator Laravel ("OK Taxi", "OK Confort", "OK Van").
  static String _backendServiceType(String value) {
    final option = kServiceTypes.firstWhere(
      (o) => o.value == value,
      orElse: () => kServiceTypes.first,
    );
    return option.label;
  }

  /// POST /v1/client/rides — Créer une demande de course.
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
    required double distanceKm,
    required int durationMin,
    required double price,
    String? recipientName,
    String? recipientPhone,
    String? packageType,
    double? packageWeightKg,
    String? deliveryInstructions,
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
          'service_type': _backendServiceType(serviceType),
          'payment_method': _backendPaymentMethod(paymentMethod),
          'estimated_price': price,
          'estimated_distance_km': distanceKm,
          'estimated_duration_min': durationMin,
          if (recipientName != null) 'recipient_name': recipientName,
          if (recipientPhone != null) 'recipient_phone': recipientPhone,
          if (packageType != null) 'package_type': packageType,
          if (packageWeightKg != null) 'package_weight_kg': packageWeightKg,
          if (deliveryInstructions != null) 'delivery_instructions': deliveryInstructions,
        }),
      );

      if (response.statusCode == 404) {
        return {
          'success': false,
          'code': 'ENDPOINT_MISSING',
          'message': "Endpoint manquant côté Laravel : POST /v1/client/rides n'existe pas.",
        };
      }

      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
        return {'success': true, 'ride': data['data']};
      }
      return {'success': false, 'message': apiErrorMessage(data, 'Impossible de créer la course.')};
    } catch (e) {
      return {
        'success': false,
        'code': 'NETWORK_ERROR',
        'message': 'Impossible de contacter le serveur.',
      };
    }
  }

  /// GET /v1/client/rides/{id} — Récupère l'état actuel d'une course
  /// (status, driver_id une fois qu'un chauffeur a accepté, infos chauffeur).
  static Future<Map<String, dynamic>> getRide(String jwtToken, String rideId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/client/rides/$rideId'),
        headers: ApiConfig.authHeaders(jwtToken),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'ride': data['data']};
      }
      return {'success': false, 'message': apiErrorMessage(data, 'Impossible de charger la course.')};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// POST /v1/client/rides/{rideId}/review — note le chauffeur/livreur
  /// (rating 1-5, commentaire optionnel). 400 si la course n'est pas
  /// completed ou si déjà notée.
  static Future<Map<String, dynamic>> reviewRide(
    String jwtToken,
    String rideId, {
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/client/rides/$rideId/review'),
        headers: ApiConfig.authHeaders(jwtToken),
        body: jsonEncode({
          'rating': rating,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        }),
      );
      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
        return {'success': true, 'review': data['data']};
      }
      return {'success': false, 'message': apiErrorMessage(data, "Impossible d'envoyer votre avis.")};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }
}