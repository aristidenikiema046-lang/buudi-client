import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/payment_request_model.dart';

class PaymentRequestService {
  /// GET /v1/payment-requests/{token} — public, mais on envoie quand même le
  /// token JWT s'il existe pour que le backend renseigne payer.can_pay_with_wallet.
  static Future<Map<String, dynamic>> getPaymentRequest(String token, {String? jwtToken}) async {
    try {
      final headers = {'Accept': 'application/json', 'Content-Type': 'application/json'};
      if (jwtToken != null && jwtToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $jwtToken';
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/payment-requests/$token'),
        headers: headers,
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'request': PaymentRequestModel.fromJson(data)};
      }
      return {'success': false, 'message': data['message'] ?? "Demande de paiement introuvable."};
    } catch (e) {
      return {'success': false, 'message': "Impossible de contacter le serveur."};
    }
  }

  /// POST /v1/payment-requests/{token}/pay-with-wallet — nécessite d'être connecté.
  static Future<Map<String, dynamic>> payWithWallet(String jwtToken, String token) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/payment-requests/$token/pay-with-wallet'),
        headers: ApiConfig.authHeaders(jwtToken),
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['message'] ?? "Impossible d'effectuer le paiement."};
    } catch (e) {
      return {'success': false, 'message': "Impossible de contacter le serveur."};
    }
  }
}