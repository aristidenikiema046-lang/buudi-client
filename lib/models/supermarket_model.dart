class Supermarket {
  final String id;
  final String businessName;
  final String? businessAddress;
  final String? logoUrl;

  Supermarket({
    required this.id,
    required this.businessName,
    this.businessAddress,
    this.logoUrl,
  });

  factory Supermarket.fromJson(Map<String, dynamic> json) => Supermarket(
        id: json['id']?.toString() ?? '',
        businessName: json['business_name']?.toString() ?? '',
        businessAddress: json['business_address']?.toString(),
        logoUrl: json['logo_url']?.toString(),
      );
}
