import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../../models/ride_draft.dart';
import '../../../models/user_model.dart';
import '../../../models/wallet_model.dart';
import '../../../services/ride_service.dart';
import '../../../services/wallet_service.dart';
import '../../../utils/formatters.dart';
import 'ride_tracking_screen.dart';

class RideConfirmationScreen extends StatefulWidget {
  final RideDraft draft;

  const RideConfirmationScreen({Key? key, required this.draft}) : super(key: key);

  @override
  State<RideConfirmationScreen> createState() => _RideConfirmationScreenState();
}

class _RideConfirmationScreenState extends State<RideConfirmationScreen> {
  static const _orange = Color(0xFFFF5722);

  WalletBalance? _wallet;
  bool _submitting = false;

  final Map<String, String> _serviceLabels = {
    'ok_taxi': 'OK Taxi',
    'ok_confort': 'OK Confort',
    'ok_van': 'OK Van',
    'delivery': 'Livraison',
  };

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? '';
  }

  Future<void> _loadWallet() async {
    final token = await _getToken();
    final result = await WalletService.getWallet(token);
    if (mounted && result['success'] == true) {
      setState(() => _wallet = result['wallet'] as WalletBalance);
    }
  }

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    final token = await _getToken();

    final result = await RideService.requestRide(
      token,
      pickupLat: widget.draft.pickupLat,
      pickupLng: widget.draft.pickupLng,
      pickupAddress: widget.draft.pickupAddress,
      destLat: widget.draft.destLat!,
      destLng: widget.draft.destLng!,
      destAddress: widget.draft.destAddress,
      serviceType: widget.draft.serviceType,
      paymentMethod: widget.draft.paymentMethod,
      distanceKm: widget.draft.distanceKm,
      durationMin: widget.draft.durationMin,
      price: widget.draft.price,
      recipientName: widget.draft.recipientName,
      recipientPhone: widget.draft.recipientPhone,
      packageType: widget.draft.packageType,
      packageWeightKg: widget.draft.packageWeightKg,
      deliveryInstructions: widget.draft.deliveryInstructions,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RideTrackingScreen(draft: widget.draft, rideData: result['ride'] as Map<String, dynamic>?)),
      );
      return;
    }

    if (result['code'] == 'ENDPOINT_MISSING') {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Endpoint manquant"),
          content: Text(result['message']?.toString() ?? ''),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Compris")),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? "Impossible de créer la course.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user as UserModel? : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Confirmation", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _buildTripRow(Icons.circle, const Color(0xFF2E7D32), draft.pickupAddress, showModify: true),
                const Padding(
                  padding: EdgeInsets.only(left: 5),
                  child: SizedBox(height: 18, child: VerticalDivider(width: 1)),
                ),
                _buildTripRow(Icons.location_on, _orange, draft.destAddress, showModify: false),
              ],
            ),
          ),
          if (draft.isDelivery) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _buildInfoRow("Destinataire", draft.recipientName ?? '—'),
                  _buildInfoRow("Téléphone", draft.recipientPhone ?? '—'),
                  if (draft.packageType?.isNotEmpty == true) _buildInfoRow("Colis", draft.packageType!),
                  if (draft.packageWeightKg != null) _buildInfoRow("Poids", "${draft.packageWeightKg} kg"),
                  if (draft.deliveryInstructions?.isNotEmpty == true)
                    _buildInfoRow("Instructions", draft.deliveryInstructions!),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _buildInfoRow("Type de service", _serviceLabels[draft.serviceType] ?? draft.serviceType),
                _buildInfoRow("Distance", "${draft.distanceKm.toStringAsFixed(1)} km"),
                _buildInfoRow("Durée estimée", "${draft.durationMin} min"),
                const Divider(height: 24),
                _buildInfoRow("Prix estimé", formatCfa(draft.price), highlight: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text("Moyen de paiement", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _buildPaymentOption(
                  value: 'wallet',
                  icon: Icons.account_balance_wallet_rounded,
                  label: "Wallet",
                  sublabel: _wallet != null ? formatCfa(_wallet!.balance) : '...',
                ),
                const Divider(height: 1, indent: 60),
                _buildPaymentOption(
                  value: 'mobile_money',
                  icon: Icons.smartphone_rounded,
                  label: "Mobile Money",
                  sublabel: user?.phone.isNotEmpty == true ? user!.phone : "Non renseigné",
                ),
                const Divider(height: 1, indent: 60),
                _buildPaymentOption(
                  value: 'card',
                  icon: Icons.credit_card_rounded,
                  label: "Carte bancaire",
                  sublabel: "Bientôt disponible",
                  disabled: true,
                ),
                const Divider(height: 1, indent: 60),
                _buildPaymentOption(
                  value: 'cash',
                  icon: Icons.payments_rounded,
                  label: "Espèces",
                  sublabel: "À payer au chauffeur",
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitting ? null : _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text("Confirmer la commande", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              "🔒 Paiement 100% sécurisé",
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripRow(IconData icon, Color color, String text, {required bool showModify}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: icon == Icons.circle ? 10 : 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text.isEmpty ? '—' : text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
        if (showModify)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text("Modifier", style: TextStyle(color: _orange, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: highlight ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: highlight ? 16 : 14,
              color: highlight ? _orange : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String value,
    required IconData icon,
    required String label,
    required String sublabel,
    bool disabled = false,
  }) {
    final isSelected = widget.draft.paymentMethod == value;
    return ListTile(
      enabled: !disabled,
      tileColor: isSelected ? const Color(0xFFFFF0EE) : null,
      onTap: disabled ? null : () => setState(() => widget.draft.paymentMethod = value),
      leading: Icon(icon, color: disabled ? Colors.grey[400] : Colors.black87),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: disabled ? Colors.grey[400] : Colors.black87)),
      subtitle: Text(sublabel, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      trailing: Radio<String>(
        value: value,
        groupValue: widget.draft.paymentMethod,
        onChanged: disabled ? null : (v) => setState(() => widget.draft.paymentMethod = v!),
        activeColor: _orange,
      ),
    );
  }
}
