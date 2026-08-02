class PaymentRequestModel {
  final String token;
  final double amount;
  final String? description;
  final String status; // pending | paid | expired
  final DateTime? expiresAt;
  final DateTime? paidAt;
  final String merchantName;
  final bool payerAuthenticated;
  final bool canPayWithWallet;

  PaymentRequestModel({
    required this.token,
    required this.amount,
    required this.status,
    required this.merchantName,
    required this.payerAuthenticated,
    required this.canPayWithWallet,
    this.description,
    this.expiresAt,
    this.paidAt,
  });

  /// Même filet de sécurité que côté marchand (MerchantPaymentRequestController::index
  /// n'appelle pas refreshExpiryStatus() par élément) : si l'échéance est dépassée
  /// mais que le statut brut reçu dit encore "pending", on l'affiche comme expirée.
  /// GET /v1/payment-requests/{token} appelle déjà refreshExpiryStatus() côté
  /// Laravel, donc ce cas ne devrait normalement pas se produire ici — mais on
  /// reste défensif plutôt que de faire confiance aveuglément au timing réseau.
  String get effectiveStatus {
    if (status == 'pending' && expiresAt != null && DateTime.now().isAfter(expiresAt!)) {
      return 'expired';
    }
    return status;
  }

  factory PaymentRequestModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final payer = json['payer'] as Map<String, dynamic>?;
    return PaymentRequestModel(
      token: data['token']?.toString() ?? '',
      amount: double.tryParse(data['amount'].toString()) ?? 0,
      description: data['description']?.toString(),
      status: data['status']?.toString() ?? 'pending',
      expiresAt: data['expires_at'] != null ? DateTime.tryParse(data['expires_at'].toString()) : null,
      paidAt: data['paid_at'] != null ? DateTime.tryParse(data['paid_at'].toString()) : null,
      merchantName: data['merchant_name']?.toString() ?? 'Marchand Buudi',
      payerAuthenticated: payer?['authenticated'] == true,
      canPayWithWallet: payer?['can_pay_with_wallet'] == true,
    );
  }
}