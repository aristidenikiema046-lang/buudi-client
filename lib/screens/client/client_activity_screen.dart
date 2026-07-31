import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/wallet_model.dart';
import '../../services/wallet_service.dart';
import '../../utils/formatters.dart';

/// Onglet "Activité" de la bottom nav. Montre l'historique réel du wallet
/// (GET /v1/client/wallet/transactions). Pas d'historique de courses ici :
/// il n'existe pas de GET /v1/client/rides (liste) côté Laravel pour l'instant,
/// seulement GET /v1/client/rides/{id} pour une course précise.
class ClientActivityScreen extends StatefulWidget {
  const ClientActivityScreen({Key? key}) : super(key: key);

  @override
  State<ClientActivityScreen> createState() => _ClientActivityScreenState();
}

class _ClientActivityScreenState extends State<ClientActivityScreen> {
  static const _orange = Color(0xFFFF5722);

  bool _loading = true;
  bool _loadingMore = false;
  List<WalletTransactionModel> _transactions = [];
  int _currentPage = 1;
  bool _hasMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(page: 1);
  }

  Future<void> _load({required int page}) async {
    setState(() {
      if (page == 1) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final result = await WalletService.getTransactions(token, page: page);
    if (!mounted) return;
    setState(() {
      _loading = false;
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
        _error = null;
      } else {
        _error = result['message'] as String?;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text("Activité", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(page: 1),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              "Historique des courses bientôt disponible ici.",
              style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            const Text(
              "Transactions",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: _orange)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(_error!, style: TextStyle(color: Colors.grey[600])),
      );
    }
    if (_transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
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
                    title: Text(
                      tx.description?.isNotEmpty == true ? tx.description! : tx.category,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
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
                  onPressed: () => _load(page: _currentPage + 1),
                  child: const Text("Charger plus", style: TextStyle(color: _orange, fontWeight: FontWeight.bold)),
                ),
        ],
      ],
    );
  }
}
