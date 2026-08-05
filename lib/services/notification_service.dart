import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/notification_model.dart';
import '../utils/api_error.dart';

class NotificationService {
  /// GET /v1/notifications — liste triée created_at desc, sans pagination.
  static Future<Map<String, dynamic>> fetchNotifications(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/notifications'),
        headers: ApiConfig.authHeaders(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final rawList = (data['data'] as List<dynamic>?) ?? [];
        final notifications = rawList.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
        return {'success': true, 'notifications': notifications};
      }
      return {'success': false, 'message': apiErrorMessage(data, 'Impossible de charger les notifications.')};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// GET /v1/notifications/unread-count → {count: N}
  static Future<Map<String, dynamic>> fetchUnreadCount(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/notifications/unread-count'),
        headers: ApiConfig.authHeaders(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final count = (data['data']?['count'] ?? data['count']) as num? ?? 0;
        return {'success': true, 'count': count.toInt()};
      }
      return {'success': false, 'message': apiErrorMessage(data, "Impossible de charger le compteur.")};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// POST /v1/notifications/{id}/read
  static Future<Map<String, dynamic>> markAsRead(String notificationId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/notifications/$notificationId/read'),
        headers: ApiConfig.authHeaders(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true};
      }
      return {'success': false, 'message': apiErrorMessage(data, 'Impossible de marquer la notification comme lue.')};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// POST /v1/notifications/read-all
  static Future<Map<String, dynamic>> markAllAsRead(String token) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/notifications/read-all'),
        headers: ApiConfig.authHeaders(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true};
      }
      return {'success': false, 'message': apiErrorMessage(data, 'Impossible de tout marquer comme lu.')};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }
}
