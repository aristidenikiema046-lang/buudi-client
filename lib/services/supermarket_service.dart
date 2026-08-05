import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/supermarket_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../utils/api_error.dart';

class SupermarketService {
  /// GET /v1/supermarkets — public, sans auth.
  static Future<Map<String, dynamic>> fetchSupermarkets() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/v1/supermarkets'));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final list = (data['data'] as List<dynamic>? ?? [])
            .map((e) => Supermarket.fromJson(e as Map<String, dynamic>))
            .toList();
        return {'success': true, 'supermarkets': list};
      }
      return {'success': false, 'message': apiErrorMessage(data, 'Impossible de charger les commerces.')};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// GET /v1/supermarkets/{merchantId}/products — public, sans auth.
  static Future<Map<String, dynamic>> fetchProducts(String merchantId) async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/v1/supermarkets/$merchantId/products'));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>;
        final supermarket = Supermarket.fromJson(payload['supermarket'] as Map<String, dynamic>);
        final products = (payload['products'] as List<dynamic>? ?? [])
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
        return {'success': true, 'supermarket': supermarket, 'products': products};
      }
      return {'success': false, 'message': apiErrorMessage(data, 'Impossible de charger le catalogue.')};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// POST /v1/client/orders — crée la commande + un PaymentRequest lié.
  /// Renvoie aussi 'paymentToken' (order.payment_request.token) pour
  /// enchaîner directement sur PaymentRequestScreen.
  static Future<Map<String, dynamic>> createOrder(
    String token, {
    required String merchantProfileId,
    required List<Map<String, dynamic>> items,
    required String deliveryAddress,
    required double deliveryLatitude,
    required double deliveryLongitude,
    required double deliveryFee,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/client/orders'),
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode({
          'merchant_profile_id': merchantProfileId,
          'items': items,
          'delivery_address': deliveryAddress,
          'delivery_latitude': deliveryLatitude,
          'delivery_longitude': deliveryLongitude,
          'delivery_fee': deliveryFee,
        }),
      );
      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
        final orderJson = data['data'] as Map<String, dynamic>;
        final paymentRequest = orderJson['payment_request'] as Map<String, dynamic>?;
        return {
          'success': true,
          'order': OrderModel.fromJson(orderJson),
          'paymentToken': paymentRequest?['token']?.toString(),
        };
      }
      return {'success': false, 'message': apiErrorMessage(data, 'Impossible de créer la commande.')};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// GET /v1/client/orders
  static Future<Map<String, dynamic>> fetchOrders(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/client/orders'),
        headers: ApiConfig.authHeaders(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final list = (data['data'] as List<dynamic>? ?? [])
            .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return {'success': true, 'orders': list};
      }
      return {'success': false, 'message': apiErrorMessage(data, 'Impossible de charger vos commandes.')};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// GET /v1/client/orders/{id}
  static Future<Map<String, dynamic>> fetchOrderDetail(String orderId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/client/orders/$orderId'),
        headers: ApiConfig.authHeaders(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'order': OrderModel.fromJson(data['data'] as Map<String, dynamic>)};
      }
      return {'success': false, 'message': apiErrorMessage(data, 'Commande introuvable.')};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// POST /v1/client/orders/{id}/cancel
  static Future<Map<String, dynamic>> cancelOrder(String orderId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/client/orders/$orderId/cancel'),
        headers: ApiConfig.authHeaders(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'order': OrderModel.fromJson(data['data'] as Map<String, dynamic>)};
      }
      return {'success': false, 'message': apiErrorMessage(data, "Impossible d'annuler la commande.")};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }
}
