import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class TransferService {
  /// POST /v1/client/transfer
  /// [operator] doit être l'un de : wave, orange, mtn, moov
  static Future<Map<String, dynamic>> transfer(
    String jwtToken, {
    required String operator,
    required String phoneNumber,
    required double amount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/client/transfer'),
        headers: ApiConfig.authHeaders(jwtToken),
        body: jsonEncode({
          'operator': operator,
          'phone_number': phoneNumber,
          'amount': amount,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 202 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': _extractError(data)};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  static String _extractError(Map<String, dynamic> data) {
    if (data['errors'] != null && data['errors'] is Map) {
      final errors = Map<String, dynamic>.from(data['errors']);
      return errors.values.expand((v) => v is List ? v : [v]).join('\n');
    }
    return data['message']?.toString() ?? 'Une erreur est survenue.';
  }
}
