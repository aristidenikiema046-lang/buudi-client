import 'package:flutter/material.dart';

import '../../../models/supermarket_model.dart';
import '../../../services/supermarket_service.dart';
import 'orders_list_screen.dart';
import 'supermarket_catalog_screen.dart';

class SupermarketListScreen extends StatefulWidget {
  const SupermarketListScreen({Key? key}) : super(key: key);

  @override
  State<SupermarketListScreen> createState() => _SupermarketListScreenState();
}

class _SupermarketListScreenState extends State<SupermarketListScreen> {
  static const _orange = Color(0xFFFF5722);

  bool _loading = true;
  String? _error;
  List<Supermarket> _supermarkets = [];

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
    final result = await SupermarketService.fetchSupermarkets();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _supermarkets = result['supermarkets'] as List<Supermarket>;
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
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Supermarché", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded, color: Colors.black),
            tooltip: "Mes commandes",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersListScreen())),
          ),
        ],
      ),
      body: _buildBody(),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(backgroundColor: _orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Réessayer", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    if (_supermarkets.isEmpty) {
      return RefreshIndicator(
        color: _orange,
        onRefresh: _load,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(child: Text("Aucun commerce disponible pour l'instant.", style: TextStyle(color: Colors.grey[600]))),
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
        itemCount: _supermarkets.length,
        itemBuilder: (context, index) => _buildCard(_supermarkets[index]),
      ),
    );
  }

  Widget _buildCard(Supermarket supermarket) {
    final hasLogo = supermarket.logoUrl != null && supermarket.logoUrl!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFFFFF0EE),
          backgroundImage: hasLogo ? NetworkImage(supermarket.logoUrl!) : null,
          child: hasLogo
              ? null
              : Text(
                  supermarket.businessName.isNotEmpty ? supermarket.businessName[0].toUpperCase() : '?',
                  style: const TextStyle(color: _orange, fontWeight: FontWeight.bold),
                ),
        ),
        title: Text(supermarket.businessName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: supermarket.businessAddress != null
            ? Text(supermarket.businessAddress!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 12))
            : null,
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupermarketCatalogScreen(supermarket: supermarket))),
      ),
    );
  }
}
