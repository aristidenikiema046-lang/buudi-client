import 'package:flutter/material.dart';

/// Écran générique "Bientôt disponible" pour les services pas encore
/// implémentés en Phase A (Livraison, Supermarché, parrainage, ...).
class ComingSoonScreen extends StatelessWidget {
  final String title;

  const ComingSoonScreen({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_empty_rounded, color: Color(0xFFFF5722), size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              "Bientôt disponible",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              "$title arrive prochainement sur Buudi.",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
