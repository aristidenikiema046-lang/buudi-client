import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'payment_request_screen.dart';

/// Scan direct du QR de paiement marchand (pas de deep linking universal/app
/// links pour ce MVP — voir la discussion avec l'utilisateur : plus simple,
/// testable sans domaine buudi.africa déployé). Le contenu scanné peut être
/// soit une URL complète (https://buudi.africa/pay/{token}), soit le token
/// brut ; les deux formats sont gérés.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({Key? key}) : super(key: key);

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  static const _orange = Color(0xFFFF5722);

  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _extractToken(String rawValue) {
    if (rawValue.startsWith('http://') || rawValue.startsWith('https://')) {
      final uri = Uri.tryParse(rawValue);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last;
      }
    }
    return rawValue.trim();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final rawValue = barcode?.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _handled = true;
    final token = _extractToken(rawValue);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PaymentRequestScreen(token: token)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Scanner un QR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: _orange, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Text(
              "Visez le QR code de paiement affiché par le marchand",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}