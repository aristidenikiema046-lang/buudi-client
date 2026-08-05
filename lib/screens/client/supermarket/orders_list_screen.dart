import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/order_model.dart';
import '../../../services/supermarket_service.dart';
import '../../../utils/formatters.dart';
import 'order_detail_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({Key? key}) : super(key: key);

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  static const _orange = Color(0xFFFF5722);

  bool _loading = true;
  String? _error;
  List<OrderModel> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final result = await SupermarketService.fetchOrders(token);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _orders = result['orders'] as List<OrderModel>;
      } else {
        _error = result['message'] as String?;
      }
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF2E7D32);
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmée';
      case 'cancelled':
        return 'Annulée';
      default:
        return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Mes commandes", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _orange));
    }
    if (_error != null) {
      return RefreshIndicator(
        color: _orange,
        onRefresh: _load,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(child: Text(_error!, style: TextStyle(color: Colors.grey[600]))),
            ),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return RefreshIndicator(
        color: _orange,
        onRefresh: _load,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(child: Text("Aucune commande pour l'instant.", style: TextStyle(color: Colors.grey[600]))),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _orange,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) => _buildTile(_orders[index]),
      ),
    );
  }

  Widget _buildTile(OrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: Color(0xFFF1F3F5), shape: BoxShape.circle),
          child: const Icon(Icons.shopping_basket_outlined, color: Colors.black54),
        ),
        title: Text(
          "Commande #${order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length)}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(formatShortDate(order.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatCfa(order.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              _statusLabel(order.status),
              style: TextStyle(fontSize: 11, color: _statusColor(order.status), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)));
          _load();
        },
      ),
    );
  }
}
