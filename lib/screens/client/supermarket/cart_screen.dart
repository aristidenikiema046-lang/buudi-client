import 'package:flutter/material.dart';

import '../../../models/cart_model.dart';
import '../../../utils/formatters.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final Cart cart;

  const CartScreen({Key? key, required this.cart}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const _orange = Color(0xFFFF5722);

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Mon panier", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: cart.isEmpty ? _buildEmpty() : _buildList(cart),
      bottomNavigationBar: cart.isEmpty ? null : _buildBottomBar(cart),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("Votre panier est vide.", style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildList(Cart cart) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cart.items.length,
      itemBuilder: (context, index) {
        final item = cart.items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      "${formatCfa(item.product.price)} × ${item.quantity} = ${formatCfa(item.lineTotal)}",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              _roundIconButton(icon: Icons.remove_rounded, onTap: () => setState(() => cart.updateQuantity(item.product.id, item.quantity - 1))),
              SizedBox(width: 26, child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
              _roundIconButton(icon: Icons.add_rounded, onTap: () => setState(() => cart.add(item.product))),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                onPressed: () => setState(() => cart.remove(item.product.id)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(Cart cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Sous-total", style: TextStyle(fontSize: 13, color: Colors.grey)),
              Text(formatCfa(cart.subtotal), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _orange)),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutScreen(cart: cart))),
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text("Commander", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _roundIconButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}
