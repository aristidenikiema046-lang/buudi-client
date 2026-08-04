import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';

import '../config/api_config.dart';
import '../models/message_model.dart';

class ChatService {
  /// GET /v1/rides/{rideId}/messages — historique trié par created_at asc.
  static Future<Map<String, dynamic>> fetchMessages(String rideId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/rides/$rideId/messages'),
        headers: ApiConfig.authHeaders(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final rawList = (data['data'] as List<dynamic>?) ?? [];
        final messages = rawList.map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
        return {'success': true, 'messages': messages};
      }
      return {'success': false, 'message': data['message'] ?? 'Impossible de charger les messages.'};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// POST /v1/rides/{rideId}/messages — envoie un message ; le backend
  /// déduit sender_id/sender_role du JWT et met à jour
  /// messages_meta/{rideId}/last_message_at côté Firebase RTDB.
  static Future<Map<String, dynamic>> sendMessage(String rideId, String content, String token) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/rides/$rideId/messages'),
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode({'content': content}),
      );
      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
        return {'success': true};
      }
      return {'success': false, 'message': data['message'] ?? "Impossible d'envoyer le message."};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// Écoute messages_meta/{rideId}/last_message_at sur Firebase Realtime DB
  /// (même pattern d'accès direct que GpsTrackerService, pas de wrapper) :
  /// émet un événement à chaque nouveau message (du client ou du chauffeur),
  /// utilisé uniquement comme signal pour déclencher un refetch REST.
  static Stream<DateTime> listenForUpdates(String rideId) {
    return FirebaseDatabase.instance.ref('messages_meta/$rideId/last_message_at').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now();
    });
  }
}
