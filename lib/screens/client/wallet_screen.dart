import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/wallet_model.dart';
import '../../services/wallet_service.dart';
import '../../utils/formatters.dart';

class WalletScreen extends StatefulWidget {
  final bool openDepositOnStart;

  const WalletScreen({Key? key, this.openDepositOnStart = false}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const _orange = Color(0xFFFF5722);

  bool _loadingWallet = true;
  WalletBalance? _wallet;
  String? _walletError;

  bool _loadingTransactions = true;
  bool _loadingMore = false;
  List<WalletTransactionModel> _transactions = [];
  int _currentPage = 1;
  bool _hasMore = false;
  String? _transactionsError;

  @override
  void initState() {
    super.initState();
    _loadAll();
    if (widget.openDepositOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAmountSheet(isDeposit: true));
    }
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? '';
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadWallet(), _loadTransactions(page: 1)]);
  }

  Future<void> _loadWallet() async {
    setState(() => _loadingWallet = true);
    final token = await _getToken();
    final result = await WalletService.getWallet(token);
    if (!mounted) return;
    setState(() {
      _loadingWallet = false;
      if (result['success'] == true) {
        _wallet = result['wallet'] as WalletBalance;
        _walletError = null;
      } else {
        _walletError = result['message'] as String?;
      }
    });
  }

  Future<void> _loadTransactions({required int page}) async {
    setState(() {
      if (page == 1) {
        _loadingTransactions = true;
      } else {
        _loadingMore = true;
      }
    });
    final token = await _getToken();
    final result = await WalletService.getTransactions(token, page: page);
    if (!mounted) return;
    setState(() {
      _loadingTransactions = false;
      _loadingMore = false;
      if (result['success'] == true) {
        final data = result['page'] as WalletTransactionsPage;
        if (page == 1) {
          _transactions = data.items;
        } else {
          _transactions.addAll(data.items);
        }
        _currentPage = data.currentPage;
        _hasMore = data.hasMore;
        _transactionsError = null;
      } else {
        _transactionsError = result['message'] as String?;
      }
    });
  }

  void _openAmountSheet({required bool isDeposit}) {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    bool submitting = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDeposit ? "Recharger mon portefeuille" : "Retirer du portefeuille",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    enabled: !submitting,
                    decoration: InputDecoration(
                      labelText: "Montant (FCFA)",
                      filled: true,
                      fillColor: const Color(0xFFF7F7F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    enabled: !submitting,
                    decoration: InputDecoration(
                      labelText: "Description (optionnel)",
                      filled: true,
                      fillColor: const Color(0xFFF7F7F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final amount = double.tryParse(amountController.text.trim());
                            if (amount == null || amount <= 0) {
                              setSheetState(() => errorText = "Entrez un montant valide.");
                              return;
                            }
                            setSheetState(() {
                              submitting = true;
                              errorText = null;
                            });
                            final token = await _getToken();
                            final result = isDeposit
                                ? await WalletService.deposit(
                                    token,
                                    amount: amount,
                                    description: descriptionController.text.trim().isEmpty
                                        ? null
                                        : descriptionController.text.trim(),
                                  )
                                : await WalletService.withdraw(
                                    token,
                                    amount: amount,
                                    description: descriptionController.text.trim().isEmpty
                                        ? null
                                        : descriptionController.text.trim(),
                                  );
                            if (result['success'] == true) {
                              if (sheetContext.mounted) Navigator.pop(sheetContext);
                              _loadAll();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(result['message']?.toString() ?? 'Opération réussie.')),
                                );
                              }
                            } else {
                              setSheetState(() {
                                submitting = false;
                                errorText = result['message']?.toString() ?? 'Une erreur est survenue.';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            isDeposit ? "Confirmer le dépôt" : "Confirmer le retrait",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Portefeuille", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBalanceCard(),
            const SizedBox(height: 24),
            const Text(
              "Historique",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            _buildHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Solde disponible", style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          const SizedBox(height: 8),
          _loadingWallet
              ? const SizedBox(
                  height: 26,
                  width: 26,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _orange),
                )
              : _walletError != null
                  ? Text(_walletError!, style: TextStyle(color: Colors.grey[400], fontSize: 14))
                  : Text(
                      formatCfa(_wallet?.balance ?? 0),
                      style: const TextStyle(color: _orange, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openAmountSheet(isDeposit: true),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text("Déposer"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openAmountSheet(isDeposit: false),
                  icon: const Icon(Icons.remove_rounded, size: 18, color: Colors.white),
                  label: const Text("Retirer", style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (_loadingTransactions) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator(color: _orange)),
      );
    }
    if (_transactionsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(_transactionsError!, style: TextStyle(color: Colors.grey[600])),
      );
    }
    if (_transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text("Aucune transaction pour le moment.", style: TextStyle(color: Colors.grey[600])),
      );
    }
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: _transactions.asMap().entries.map((entry) {
              final tx = entry.value;
              final isCredit = tx.isCredit;
              return Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFF1F3F5),
                      child: Icon(
                        isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: isCredit ? const Color(0xFF2E7D32) : Colors.black54,
                        size: 18,
                      ),
                    ),
                    title: Text(tx.description?.isNotEmpty == true ? tx.description! : tx.category,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(formatShortDate(tx.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    trailing: Text(
                      "${isCredit ? '+' : '-'}${formatCfa(tx.amount)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCredit ? const Color(0xFF2E7D32) : Colors.black87,
                      ),
                    ),
                  ),
                  if (entry.key != _transactions.length - 1) const Divider(height: 1, indent: 60),
                ],
              );
            }).toList(),
          ),
        ),
        if (_hasMore) ...[
          const SizedBox(height: 12),
          _loadingMore
              ? const CircularProgressIndicator(color: _orange)
              : TextButton(
                  onPressed: () => _loadTransactions(page: _currentPage + 1),
                  child: const Text("Charger plus", style: TextStyle(color: _orange, fontWeight: FontWeight.bold)),
                ),
        ],
      ],
    );
  }
}
