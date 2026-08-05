import 'package:flutter/material.dart';

import '../../../models/cart_model.dart';
import '../../../models/product_model.dart';
import '../../../models/supermarket_model.dart';
import '../../../services/supermarket_service.dart';
import '../../../utils/formatters.dart';
import 'cart_screen.dart';

class SupermarketCatalogScreen extends StatefulWidget {
  final Supermarket supermarket;

  const SupermarketCatalogScreen({Key? key, required this.supermarket}) : super(key: key);

  @override
  State<SupermarketCatalogScreen> createState() => _SupermarketCatalogScreenState();
}

class _SupermarketCatalogScreenState extends State<SupermarketCatalogScreen> {
  static const _orange = Color(0xFFFF5722);

  bool _loading = true;
  String? _error;
  List<Product> _products = [];
  late final Cart _cart;

  @override
  void initState() {
    super.initState();
    _cart = Cart(merchantProfileId: widget.supermarket.id, merchantName: widget.supermarket.businessName);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await SupermarketService.fetchProducts(widget.supermarket.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _products = result['products'] as List<Product>;
      } else {
        _error = result['message'] as String?;
      }
    });
  }

  void _openCart() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen(cart: _cart)));
    setState(() {}); // reflète les changements faits depuis l'écran panier
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(widget.supermarket.businessName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _buildBody(),
      floatingActionButton: _cart.totalItems > 0
          ? FloatingActionButton.extended(
              backgroundColor: _orange,
              onPressed: _openCart,
              icon: const Icon(Icons.shopping_cart_rounded, color: Colors.white),
              label: Text(
                "Voir le panier (${_cart.totalItems}) · ${formatCfa(_cart.subtotal)}",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _orange));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
        ),
      );
    }
    if (_products.isEmpty) {
      return Center(child: Text("Aucun produit disponible pour l'instant.", style: TextStyle(color: Colors.grey[600])));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: _products.length,
      itemBuilder: (context, index) => _buildProductCard(_products[index]),
    );
  }

  Widget _buildProductCard(Product product) {
    final quantity = _cart.quantityFor(product.id);
    final hasImage = product.imageUrl != null && product.imageUrl!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(12),
              image: hasImage ? DecorationImage(image: NetworkImage(product.imageUrl!), fit: BoxFit.cover) : null,
            ),
            child: hasImage ? null : const Icon(Icons.shopping_basket_outlined, color: Colors.black45),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (product.category != null) ...[
                  const SizedBox(height: 2),
                  Text(product.category!, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
                const SizedBox(height: 4),
                Text(formatCfa(product.price), style: const TextStyle(color: _orange, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          quantity == 0
              ? _roundIconButton(icon: Icons.add_rounded, onTap: () => setState(() => _cart.add(product)))
              : Row(
                  children: [
                    _roundIconButton(
                      icon: Icons.remove_rounded,
                      onTap: () => setState(() => _cart.updateQuantity(product.id, quantity - 1)),
                    ),
                    SizedBox(
                      width: 26,
                      child: Text('$quantity', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    _roundIconButton(
                      icon: Icons.add_rounded,
                      onTap: () => setState(() => _cart.add(product)),
                    ),
                  ],
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
        width: 30,
        height: 30,
        decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
