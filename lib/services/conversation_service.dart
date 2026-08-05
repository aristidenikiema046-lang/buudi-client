import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/conversation_model.dart';
import '../utils/api_error.dart';

class ConversationService {
  /// GET /v1/conversations — liste des rides avec messages, triée par
  /// dernier message desc (tri déjà fait côté API).
  static Future<Map<String, dynamic>> fetchConversations(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/conversations'),
        headers: ApiConfig.authHeaders(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final list = (data['data'] as List<dynamic>? ?? [])
            .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
            .toList();
        return {'success': true, 'conversations': list};
      }
      return {'success': false, 'message': apiErrorMessage(data, 'Impossible de charger les conversations.')};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// POST /v1/rides/{rideId}/messages/mark-read
  static Future<Map<String, dynamic>> markConversationRead(String rideId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/rides/$rideId/messages/mark-read'),
        headers: ApiConfig.authHeaders(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true};
      }
      return {'success': false, 'message': apiErrorMessage(data, 'Impossible de marquer la conversation comme lue.')};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }
}
