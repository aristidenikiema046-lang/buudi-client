import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/payment_request_model.dart';
import '../../services/payment_request_service.dart';
import '../../utils/formatters.dart';

class PaymentRequestScreen extends StatefulWidget {
  final String token;

  const PaymentRequestScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<PaymentRequestScreen> createState() => _PaymentRequestScreenState();
}

class _PaymentRequestScreenState extends State<PaymentRequestScreen> {
  static const _orange = Color(0xFFFF5722);

  bool _loading = true;
  String? _loadError;
  PaymentRequestModel? _request;
  bool _paying = false;
  bool _paidJustNow = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? '';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final token = await _getToken();
    final result = await PaymentRequestService.getPaymentRequest(widget.token, jwtToken: token);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _request = result['request'] as PaymentRequestModel;
      } else {
        _loadError = result['message']?.toString() ?? "Demande de paiement introuvable.";
      }
    });
  }

  Future<void> _pay() async {
    setState(() => _paying = true);
    final token = await _getToken();
    final result = await PaymentRequestService.payWithWallet(token, widget.token);
    if (!mounted) return;
    setState(() => _paying = false);

    if (result['success'] == true) {
      setState(() => _paidJustNow = true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? "Impossible d'effectuer le paiement.")),
    );
    // Le statut a pu changer entre-temps (expirée, déjà payée par un double scan) :
    // on rafraîchit pour refléter l'état réel plutôt que de laisser le bouton "Payer" affiché.
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Paiement", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _orange));
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(_loadError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    final request = _request!;

    if (_paidJustNow || request.effectiveStatus == 'paid') {
      return _buildStatusMessage(
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF2E7D32),
        title: "Paiement effectué",
        subtitle: "Votre paiement de ${formatCfa(request.amount)} à ${request.merchantName} a bien été réalisé.",
      );
    }

    if (request.effectiveStatus == 'expired') {
      return _buildStatusMessage(
        icon: Icons.timer_off_rounded,
        color: Colors.grey[500]!,
        title: "Demande expirée",
        subtitle: "Cette demande de paiement n'est plus valide. Demandez au marchand d'en générer une nouvelle.",
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFFFF0EE),
                  child: Text(
                    request.merchantName.isNotEmpty ? request.merchantName[0].toUpperCase() : '?',
                    style: const TextStyle(color: _orange, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(request.merchantName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Text(
                  formatCfa(request.amount),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _orange),
                ),
                if (request.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    request.description!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 30),
          if (!request.payerAuthenticated)
            _infoBanner("Connectez-vous à votre compte Buudi pour payer cette demande avec votre wallet.")
          else if (!request.canPayWithWallet)
            _infoBanner("Cette demande ne peut pas être payée avec votre compte.")
          else
            ElevatedButton(
              onPressed: _paying ? null : _pay,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _paying
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      "Payer ${formatCfa(request.amount)} avec mon wallet Buudi",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _infoBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.grey[600], size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: Colors.grey[700], fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildStatusMessage({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                minimumSize: const Size(200, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text("Retour à l'accueil", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}