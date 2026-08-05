class Product {
  final String id;
  final String merchantProfileId;
  final String name;
  final String? description;
  final double price;
  final String? category;
  final String? imageUrl;
  final bool isAvailable;
  final int? stockQuantity;

  Product({
    required this.id,
    required this.merchantProfileId,
    required this.name,
    required this.price,
    this.description,
    this.category,
    this.imageUrl,
    this.isAvailable = true,
    this.stockQuantity,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id']?.toString() ?? '',
        merchantProfileId: json['merchant_profile_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        price: double.tryParse(json['price'].toString()) ?? 0,
        category: json['category']?.toString(),
        imageUrl: json['image_url']?.toString(),
        isAvailable: json['is_available'] == true || json['is_available'] == 1,
        stockQuantity: json['stock_quantity'] != null ? int.tryParse(json['stock_quantity'].toString()) : null,
      );
}
