import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/transfer_service.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({Key? key}) : super(key: key);

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  static const _orange = Color(0xFFFF5722);

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String _operator = 'wave';
  bool _submitting = false;
  String? _errorText;

  final List<Map<String, dynamic>> _operators = const [
    {'value': 'wave', 'label': 'Wave', 'color': Color(0xFF1DA1F2)},
    {'value': 'orange', 'label': 'Orange Money', 'color': Color(0xFFFF7900)},
    {'value': 'mtn', 'label': 'MTN Mobile Money', 'color': Color(0xFFFFCC08)},
    {'value': 'moov', 'label': 'Moov Money', 'color': Color(0xFF0072BC)},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (phone.isEmpty) {
      setState(() => _errorText = "Entrez un numéro de téléphone.");
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _errorText = "Entrez un montant valide.");
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final result = await TransferService.transfer(
      token,
      operator: _operator,
      phoneNumber: phone,
      amount: amount,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Transfert initié.')),
      );
      Navigator.pop(context);
    } else {
      setState(() {
        _submitting = false;
        _errorText = result['message']?.toString() ?? 'Une erreur est survenue.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Envoyer de l'argent", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              const Text(
                "Choisissez un opérateur",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.4,
                children: _operators.map((op) {
                  final isSelected = _operator == op['value'];
                  return GestureDetector(
                    onTap: _submitting ? null : () => setState(() => _operator = op['value'] as String),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? (op['color'] as Color).withOpacity(0.1) : const Color(0xFFF7F7F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? op['color'] as Color : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: op['color'] as Color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              op['label'] as String,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                "Numéro de téléphone",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_submitting,
                decoration: InputDecoration(
                  hintText: "+225 07 12 34 56 78",
                  prefixIcon: const Icon(Icons.phone_android_rounded, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF7F7F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Montant (FCFA)",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                enabled: !_submitting,
                decoration: InputDecoration(
                  hintText: "0",
                  prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF7F7F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 14),
                Text(_errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        "Envoyer",
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
