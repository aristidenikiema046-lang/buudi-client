class OrderItemModel {
  final String productName;
  final double unitPrice;
  final int quantity;
  final double lineTotal;

  OrderItemModel({
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => OrderItemModel(
        productName: json['product_name']?.toString() ?? '',
        unitPrice: double.tryParse(json['unit_price'].toString()) ?? 0,
        quantity: int.tryParse(json['quantity'].toString()) ?? 0,
        lineTotal: double.tryParse(json['line_total'].toString()) ?? 0,
      );
}

class OrderModel {
  final String id;
  final String merchantProfileId;
  final String status; // pending | confirmed | cancelled
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? rideId;
  // JSON brut de la relation `ride` (Order::with(['ride'])) : présent une
  // fois la commande confirmée par le marchand. Contient pickup/destination
  // réels + driver_id/status, exploitable tel quel par RideTrackingScreen.
  final Map<String, dynamic>? ride;
  final DateTime createdAt;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.merchantProfileId,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.deliveryAddress,
    required this.createdAt,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.rideId,
    this.ride,
    this.items = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id: json['id']?.toString() ?? '',
        merchantProfileId: json['merchant_profile_id']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        subtotal: double.tryParse(json['subtotal'].toString()) ?? 0,
        deliveryFee: double.tryParse(json['delivery_fee'].toString()) ?? 0,
        total: double.tryParse(json['total'].toString()) ?? 0,
        deliveryAddress: json['delivery_address']?.toString() ?? '',
        deliveryLatitude: json['delivery_latitude'] != null ? double.tryParse(json['delivery_latitude'].toString()) : null,
        deliveryLongitude: json['delivery_longitude'] != null ? double.tryParse(json['delivery_longitude'].toString()) : null,
        rideId: json['ride_id']?.toString(),
        ride: json['ride'] is Map ? Map<String, dynamic>.from(json['ride'] as Map) : null,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
