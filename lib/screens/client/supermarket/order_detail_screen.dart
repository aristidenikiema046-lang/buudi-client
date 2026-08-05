import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/order_model.dart';
import '../../../models/ride_draft.dart';
import '../../../services/supermarket_service.dart';
import '../../../utils/formatters.dart';
import '../vtc/ride_tracking_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  static const _orange = Color(0xFFFF5722);

  bool _loading = true;
  bool _cancelling = false;
  String? _error;
  OrderModel? _order;
  String _token = '';

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
    _token = prefs.getString('jwt_token') ?? '';
    final result = await SupermarketService.fetchOrderDetail(widget.orderId, _token);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _order = result['order'] as OrderModel;
      } else {
        _error = result['message'] as String?;
      }
    });
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Annuler la commande ?"),
        content: const Text("Cette action est définitive. Si la commande a déjà été payée, vous serez remboursé."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Retour")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Annuler la commande", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _cancelling = true);
    final result = await SupermarketService.cancelOrder(widget.orderId, _token);
    if (!mounted) return;
    setState(() => _cancelling = false);

    if (result['success'] == true) {
      setState(() => _order = result['order'] as OrderModel);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? "Impossible d'annuler la commande.")),
      );
    }
  }

  /// Construit un RideDraft à partir de la relation `ride` déjà chargée par
  /// GET /v1/client/orders/{id} (Order::with(['ride'])) : pickup = vraies
  /// coordonnées GPS du supermarché (Merchant\OrderController::confirm),
  /// destination = adresse de livraison. Aucune donnée approximée.
  void _trackDelivery() {
    final ride = _order?.ride;
    if (ride == null) return;
    final draft = RideDraft(
      pickupLat: double.tryParse(ride['pickup_latitude'].toString()) ?? 0,
      pickupLng: double.tryParse(ride['pickup_longitude'].toString()) ?? 0,
      pickupAddress: ride['pickup_address']?.toString() ?? '',
      destLat: double.tryParse(ride['destination_latitude'].toString()),
      destLng: double.tryParse(ride['destination_longitude'].toString()),
      destAddress: ride['destination_address']?.toString() ?? '',
      serviceType: 'delivery',
      price: double.tryParse(ride['price'].toString()) ?? _order!.deliveryFee,
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => RideTrackingScreen(draft: draft, rideData: ride)));
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
        title: const Text("Détail de la commande", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _orange));
    }
    if (_error != null || _order == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error ?? "Commande introuvable.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
        ),
      );
    }

    final order = _order!;
    final shortId = order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Commande #$shortId", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _statusColor(order.status).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(_statusLabel(order.status), style: TextStyle(color: _statusColor(order.status), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text("Articles", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: order.items.asMap().entries.map((entry) {
              final item = entry.value;
              return Column(
                children: [
                  ListTile(
                    title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text("${formatCfa(item.unitPrice)} × ${item.quantity}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    trailing: Text(formatCfa(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  if (entry.key != order.items.length - 1) const Divider(height: 1, indent: 16),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              _row("Sous-total", formatCfa(order.subtotal)),
              const SizedBox(height: 8),
              _row("Frais de livraison", formatCfa(order.deliveryFee)),
              const Divider(height: 24),
              _row("Total", formatCfa(order.total), highlight: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text("Adresse de livraison", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: _orange, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(order.deliveryAddress, style: const TextStyle(fontSize: 13))),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (order.rideId != null && order.ride != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton.icon(
              onPressed: _trackDelivery,
              icon: const Icon(Icons.local_shipping_outlined, color: Colors.white),
              label: const Text("Suivre la livraison", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        if (order.status == 'pending')
          OutlinedButton(
            onPressed: _cancelling ? null : _cancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _cancelling
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                : const Text("Annuler la commande", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: highlight ? 15 : 13, color: highlight ? Colors.black87 : Colors.grey[600], fontWeight: highlight ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: highlight ? 17 : 13, fontWeight: FontWeight.bold, color: highlight ? _orange : Colors.black87)),
      ],
    );
  }
}
