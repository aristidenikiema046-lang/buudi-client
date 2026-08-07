import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/ride_service.dart';

/// Affiché une fois la course marquée 'completed' (voir
/// RideTrackingScreen._refreshRide). Notation facultative : "Passer" ramène
/// directement à l'accueil sans appel API, comme le ferait le bouton "X" de
/// l'écran de suivi.
class RatingScreen extends StatefulWidget {
  final String rideId;
  final String driverLabel; // "chauffeur" | "livreur"
  final String? driverName;

  const RatingScreen({Key? key, required this.rideId, required this.driverLabel, this.driverName}) : super(key: key);

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  static const _orange = Color(0xFFFF5722);

  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _skip() {
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  Future<void> _submit() async {
    if (_rating == 0 || _submitting) return;

    setState(() => _submitting = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final result = await RideService.reviewRide(
      token,
      widget.rideId,
      rating: _rating,
      comment: _commentController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Merci pour votre avis !"), backgroundColor: Color(0xFF2E7D32)),
      );
      Navigator.popUntil(context, (r) => r.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? "Impossible d'envoyer votre avis.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.driverName?.isNotEmpty == true ? widget.driverName! : "votre ${widget.driverLabel}";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text("Course terminée", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.check_circle_rounded, size: 64, color: Color(0xFF2E7D32)),
            const SizedBox(height: 16),
            Text(
              "Comment s'est passée votre course avec $name ?",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                final filled = starValue <= _rating;
                return IconButton(
                  onPressed: () => setState(() => _rating = starValue),
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 40,
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Un commentaire (optionnel)",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: (_rating > 0 && !_submitting) ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                disabledBackgroundColor: Colors.grey[300],
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text("Envoyer", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _submitting ? null : _skip,
              child: Text("Passer", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
