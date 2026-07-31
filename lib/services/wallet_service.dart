import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/wallet_model.dart';

class WalletService {
  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// GET /v1/client/wallet
  static Future<Map<String, dynamic>> getWallet(String jwtToken) async {
    try {
      final response = await http.get(_uri('/v1/client/wallet'), headers: ApiConfig.authHeaders(jwtToken));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'wallet': WalletBalance.fromJson(data['data'])};
      }
      return {'success': false, 'message': data['message'] ?? 'Impossible de charger le portefeuille.'};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// GET /v1/client/wallet/transactions (paginé, 20 par page côté serveur)
  static Future<Map<String, dynamic>> getTransactions(String jwtToken, {int page = 1}) async {
    try {
      final response = await http.get(
        _uri('/v1/client/wallet/transactions?page=$page'),
        headers: ApiConfig.authHeaders(jwtToken),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'page': WalletTransactionsPage.fromJson(data['data'])};
      }
      return {'success': false, 'message': data['message'] ?? 'Impossible de charger les transactions.'};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// POST /v1/client/wallet/deposit
  static Future<Map<String, dynamic>> deposit(
    String jwtToken, {
    required double amount,
    String? description,
  }) async {
    return _postAmount(jwtToken, '/v1/client/wallet/deposit', amount, description);
  }

  /// POST /v1/client/wallet/withdraw
  static Future<Map<String, dynamic>> withdraw(
    String jwtToken, {
    required double amount,
    String? description,
  }) async {
    return _postAmount(jwtToken, '/v1/client/wallet/withdraw', amount, description);
  }

  static Future<Map<String, dynamic>> _postAmount(
    String jwtToken,
    String path,
    double amount,
    String? description,
  ) async {
    try {
      final response = await http.post(
        _uri(path),
        headers: ApiConfig.authHeaders(jwtToken),
        body: jsonEncode({
          'amount': amount,
          if (description != null) 'description': description,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
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
