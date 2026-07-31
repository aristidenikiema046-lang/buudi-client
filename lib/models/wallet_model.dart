class WalletBalance {
  final double balance;
  final String currency;

  WalletBalance({required this.balance, required this.currency});

  factory WalletBalance.fromJson(Map<String, dynamic> json) => WalletBalance(
        balance: double.tryParse(json['balance'].toString()) ?? 0,
        currency: json['currency']?.toString() ?? 'XOF',
      );
}

class WalletTransactionModel {
  final String id;
  final double amount;
  final String type; // credit | debit
  final String category; // deposit | withdrawal | transfer_wave | transfer_orange | ...
  final String? description;
  final String status; // completed | pending
  final DateTime createdAt;

  WalletTransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.status,
    required this.createdAt,
    this.description,
  });

  bool get isCredit => type == 'credit';

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) => WalletTransactionModel(
        id: json['id']?.toString() ?? '',
        amount: double.tryParse(json['amount'].toString()) ?? 0,
        type: json['type']?.toString() ?? 'debit',
        category: json['category']?.toString() ?? '',
        description: json['description']?.toString(),
        status: json['status']?.toString() ?? 'completed',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class WalletTransactionsPage {
  final List<WalletTransactionModel> items;
  final int currentPage;
  final int lastPage;

  WalletTransactionsPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  bool get hasMore => currentPage < lastPage;

  factory WalletTransactionsPage.fromJson(Map<String, dynamic> json) {
    final rawList = (json['data'] as List<dynamic>?) ?? [];
    return WalletTransactionsPage(
      items: rawList
          .map((e) => WalletTransactionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
    );
  }
}
