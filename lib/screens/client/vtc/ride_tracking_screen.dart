import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/ride_draft.dart';
import '../../../utils/formatters.dart';

/// Étape 3 du flux VTC : "Suivi en cours".
///
/// NOTE IMPORTANTE : cet écran ne peut pas être testé de bout en bout tant que
/// POST /v1/client/rides n'existe pas côté Laravel (voir ride_service.dart) —
/// on ne peut donc pas obtenir de vrai driver_id à écouter. Le code est prêt :
/// il écoute Firebase Realtime Database sur `drivers_location/{driverId}`,
/// exactement le chemin déjà utilisé par GpsTrackerService côté chauffeur
/// (lib/services/gps_tracker_service.dart), donc la connexion sera immédiate
/// une fois qu'un vrai driver_id circulera.
class RideTrackingScreen extends StatefulWidget {
  final RideDraft draft;
  final Map<String, dynamic>? rideData;

  const RideTrackingScreen({Key? key, required this.draft, this.rideData}) : super(key: key);

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  static const _orange = Color(0xFFFF5722);

  bool _detailsExpanded = false;
  StreamSubscription<DatabaseEvent>? _locationSub;
  LatLng? _driverPosition;

  String? get _driverId => widget.rideData?['driver_id']?.toString();

  @override
  void initState() {
    super.initState();
    final driverId = _driverId;
    if (driverId != null) {
      _locationSub = FirebaseDatabase.instance.ref('drivers_location/$driverId').onValue.listen((event) {
        final value = event.snapshot.value;
        if (value is Map) {
          final lat = (value['latitude'] as num?)?.toDouble();
          final lng = (value['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null && mounted) {
            setState(() => _driverPosition = LatLng(lat, lng));
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.rideData;
    final driverName = ride?['driver_name']?.toString() ?? "Recherche d'un chauffeur...";
    final driverRating = ride?['driver_rating']?.toString() ?? '-';
    final vehicle = ride?['vehicle']?.toString() ?? '';
    final status = ride?['status']?.toString() ?? 'searching';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.black), onPressed: () => Navigator.popUntil(context, (r) => r.isFirst)),
        title: const Text("En cours", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.headset_mic_outlined, color: Colors.black))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const CircleAvatar(radius: 26, backgroundColor: Color(0xFFFFF0EE), child: Icon(Icons.person, color: _orange)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                            Text(" $driverRating", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            if (vehicle.isNotEmpty) Text(" • $vehicle", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle),
                    child: IconButton(icon: const Icon(Icons.call_rounded, color: Colors.white), onPressed: () {}),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildStatusStepper(status),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: LatLng(widget.draft.pickupLat, widget.draft.pickupLng), zoom: 13),
                  zoomControlsEnabled: false,
                  markers: {
                    Marker(markerId: const MarkerId('pickup'), position: LatLng(widget.draft.pickupLat, widget.draft.pickupLng)),
                    if (widget.draft.destLat != null)
                      Marker(
                        markerId: const MarkerId('destination'),
                        position: LatLng(widget.draft.destLat!, widget.draft.destLng!),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                      ),
                    if (_driverPosition != null)
                      Marker(
                        markerId: const MarkerId('driver'),
                        position: _driverPosition!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                      ),
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    title: const Text("Détails de la course", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    trailing: Icon(_detailsExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                    onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
                  ),
                  if (_detailsExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          _detailRow("Départ", widget.draft.pickupAddress),
                          _detailRow("Arrivée", widget.draft.destAddress),
                          _detailRow("Prix", formatCfa(widget.draft.price)),
                          _detailRow("Paiement", _paymentLabel(widget.draft.paymentMethod)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _actionButton(Icons.chat_bubble_outline_rounded, "Contacter", () {})),
                    const SizedBox(width: 10),
                    Expanded(child: _actionButton(Icons.close_rounded, "Annuler", () => Navigator.popUntil(context, (r) => r.isFirst))),
                    const SizedBox(width: 10),
                    Expanded(child: _actionButton(Icons.share_rounded, "Partager", () {})),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.headset_mic_rounded, color: _orange, size: 18),
                  label: const Text("Besoin d'aide ?", style: TextStyle(color: _orange, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46),
                    side: const BorderSide(color: _orange),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStepper(String status) {
    const steps = ['En approvisionnement', 'En route', 'Arrivé'];
    final currentIndex = status == 'in_progress' ? 1 : (status == 'completed' ? 2 : 0);
    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index <= currentIndex;
        return Expanded(
          child: Column(
            children: [
              Container(height: 4, decoration: BoxDecoration(color: isActive ? _orange : Colors.grey[300], borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 6),
              Text(steps[index], style: TextStyle(fontSize: 10, color: isActive ? _orange : Colors.grey[500], fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'wallet':
        return 'Wallet';
      case 'mobile_money':
        return 'Mobile Money';
      case 'card':
        return 'Carte bancaire';
      default:
        return 'Espèces';
    }
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }
}
