import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/cart_model.dart';
import '../../../services/supermarket_service.dart';
import '../../../utils/formatters.dart';
import '../payment_request_screen.dart';
import '../vtc/destination_search_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Cart cart;

  const CheckoutScreen({Key? key, required this.cart}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _orange = Color(0xFFFF5722);

  // TODO: calcul dynamique par distance (comme le flux VTC via Google
  // Directions) une fois que le point de départ (position du supermarché)
  // sera exploitable pour ce calcul côté client. Frais fixe pour ce MVP.
  static const double _deliveryFee = 1000;

  DestinationResult? _deliveryLocation;
  bool _submitting = false;

  Future<void> _pickAddress() async {
    final result = await Navigator.push<DestinationResult>(
      context,
      MaterialPageRoute(builder: (_) => const DestinationSearchScreen()),
    );
    if (result != null) {
      setState(() => _deliveryLocation = result);
    }
  }

  Future<void> _submit() async {
    if (_deliveryLocation == null || _submitting) return;

    setState(() => _submitting = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final result = await SupermarketService.createOrder(
      token,
      merchantProfileId: widget.cart.merchantProfileId,
      items: widget.cart.items.map((i) => {'product_id': i.product.id, 'quantity': i.quantity}).toList(),
      deliveryAddress: _deliveryLocation!.address,
      deliveryLatitude: _deliveryLocation!.lat,
      deliveryLongitude: _deliveryLocation!.lng,
      deliveryFee: _deliveryFee,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      final paymentToken = result['paymentToken'] as String?;
      if (paymentToken == null || paymentToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Commande créée, mais le lien de paiement est introuvable.")),
        );
        return;
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentRequestScreen(token: paymentToken)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? "Impossible de créer la commande.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    final total = cart.subtotal + _deliveryFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Livraison & paiement", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Adresse de livraison", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickAddress,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: _orange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _deliveryLocation?.address ?? "Choisir une adresse de livraison",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _deliveryLocation == null ? Colors.grey[500] : Colors.black87,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text("Récapitulatif", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _summaryRow("Sous-total (${cart.totalItems} article${cart.totalItems > 1 ? 's' : ''})", formatCfa(cart.subtotal)),
                  const SizedBox(height: 8),
                  _summaryRow("Frais de livraison", formatCfa(_deliveryFee)),
                  const Divider(height: 24),
                  _summaryRow("Total", formatCfa(total), highlight: true),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: (_deliveryLocation != null && !_submitting) ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                disabledBackgroundColor: Colors.grey[300],
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text("Confirmer et payer", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: highlight ? 15 : 13, color: highlight ? Colors.black87 : Colors.grey[600], fontWeight: highlight ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: highlight ? 17 : 13, fontWeight: FontWeight.bold, color: highlight ? _orange : Colors.black87)),
      ],
    );
  }
}
