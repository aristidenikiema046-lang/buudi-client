import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class DirectionsResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMin;

  DirectionsResult({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
  });
}

/// Appelle l'API Google Directions pour obtenir un itinéraire routier réel
/// (tracé + distance + durée), au lieu de la ligne droite / estimation à vol
/// d'oiseau utilisées avant l'activation de l'API.
class DirectionsService {
  static Future<Map<String, dynamic>> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
        'origin': '$originLat,$originLng',
        'destination': '$destLat,$destLng',
        'mode': 'driving',
        'key': ApiConfig.googleMapsApiKey,
      });

      final response = await http.get(uri);
      final data = jsonDecode(response.body);

      if (data['status'] != 'OK') {
        return {
          'success': false,
          'message': data['error_message'] ?? "Itinéraire introuvable (${data['status']}).",
        };
      }

      final routes = data['routes'] as List;
      if (routes.isEmpty) {
        return {'success': false, 'message': "Aucun itinéraire trouvé."};
      }

      final leg = routes[0]['legs'][0];
      final overviewPolyline = routes[0]['overview_polyline']['points'] as String;

      return {
        'success': true,
        'result': DirectionsResult(
          points: _decodePolyline(overviewPolyline),
          distanceKm: (leg['distance']['value'] as num) / 1000,
          durationMin: ((leg['duration']['value'] as num) / 60).round(),
        ),
      };
    } catch (e) {
      return {'success': false, 'message': "Impossible de calculer l'itinéraire."};
    }
  }

  /// Décodage de l'algorithme "encoded polyline" de Google (précision 5).
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}