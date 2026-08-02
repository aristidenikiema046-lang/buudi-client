import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/ride_draft.dart';
import '../../../services/directions_service.dart';
import '../../../services/ride_service.dart';
import '../../../utils/formatters.dart';
import '../../../utils/map_icons.dart';

/// Étape 3 du flux VTC : "Suivi en cours".
///
/// La position du chauffeur vient de Firebase Realtime DB
/// (`drivers_location/{driverId}`, écrite par buudi_partner_app toutes les
/// 5 secondes). Mais `driver_id` n'existe pas encore au moment de la création
/// de la course (POST /v1/client/rides) — il n'est renseigné qu'une fois
/// qu'un chauffeur accepte, côté Laravel (DriverRideController::acceptRide).
/// Cet écran rafraîchit donc régulièrement GET /v1/client/rides/{id} pour
/// détecter l'apparition du driver_id (et les changements de statut), et ne
/// démarre l'écoute Firebase qu'à ce moment-là.
class RideTrackingScreen extends StatefulWidget {
  final RideDraft draft;
  final Map<String, dynamic>? rideData;

  const RideTrackingScreen({Key? key, required this.draft, this.rideData}) : super(key: key);

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  static const _orange = Color(0xFFFF5722);
  static const _driverStaleAfter = Duration(seconds: 30);
  static const _routeRecomputeMinInterval = Duration(seconds: 15);

  bool _detailsExpanded = false;

  Map<String, dynamic>? _ride;
  Timer? _ridePollTimer;

  StreamSubscription<DatabaseEvent>? _locationSub;
  LatLng? _driverPosition;
  double? _driverHeading;
  DateTime? _driverUpdatedAt;
  BitmapDescriptor? _carIcon;
  double? _carIconHeading;

  List<LatLng>? _routePoints;
  DateTime? _lastRouteRecompute;

  Timer? _stalenessTicker;

  String get _rideId => widget.rideData?['id']?.toString() ?? '';
  String? get _driverId => _ride?['driver_id']?.toString();
  bool get _isDelivery => widget.draft.isDelivery;
  String get _driverWord => _isDelivery ? 'livreur' : 'chauffeur';

  bool get _isDriverLive {
    if (_driverPosition == null || _driverUpdatedAt == null) return false;
    return DateTime.now().difference(_driverUpdatedAt!) < _driverStaleAfter;
  }

  @override
  void initState() {
    super.initState();
    _ride = widget.rideData;

    if (_rideId.isNotEmpty) {
      _refreshRide();
      _ridePollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _refreshRide());
    }

    // Force un re-rendu périodique pour réévaluer la fraîcheur de la position
    // (le badge "Connexion au chauffeur..." doit apparaître même sans nouvel
    // événement Firebase, simplement parce que le temps a passé).
    _stalenessTicker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ridePollTimer?.cancel();
    _stalenessTicker?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? '';
  }

  Future<void> _refreshRide() async {
    final token = await _getToken();
    final result = await RideService.getRide(token, _rideId);
    if (!mounted || result['success'] != true) return;

    final newRide = result['ride'] as Map<String, dynamic>;
    final previousDriverId = _driverId;

    setState(() => _ride = newRide);

    final newDriverId = _ride?['driver_id']?.toString();
    if (newDriverId != null && newDriverId.isNotEmpty && newDriverId != previousDriverId) {
      _startDriverLocationListener(newDriverId);
    }

    final status = _ride?['status']?.toString();
    if (status == 'completed' || status == 'cancelled') {
      _ridePollTimer?.cancel();
    }
  }

  void _startDriverLocationListener(String driverId) {
    _locationSub?.cancel();
    _locationSub = FirebaseDatabase.instance.ref('drivers_location/$driverId').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is! Map) return;

      final lat = (value['latitude'] as num?)?.toDouble();
      final lng = (value['longitude'] as num?)?.toDouble();
      final heading = (value['heading'] as num?)?.toDouble();
      final updatedAtRaw = value['updated_at'];
      final updatedAt = updatedAtRaw is int
          ? DateTime.fromMillisecondsSinceEpoch(updatedAtRaw)
          : DateTime.now();

      if (lat == null || lng == null || !mounted) return;

      setState(() {
        _driverPosition = LatLng(lat, lng);
        _driverHeading = heading;
        _driverUpdatedAt = updatedAt;
      });

      _updateCarIcon();
      _maybeRecomputeRoute();
    });
  }

  Future<void> _updateCarIcon() async {
    final heading = _driverHeading ?? 0;
    if (_carIcon != null && _carIconHeading == heading) return;
    final icon = await createRotatedMarkerIcon(
      iconData: Icons.navigation_rounded,
      color: _orange,
      rotationDegrees: heading,
    );
    if (!mounted) return;
    setState(() {
      _carIcon = icon;
      _carIconHeading = heading;
    });
  }

  /// Recalcule le tracé chauffeur -> destination via l'API Directions, au
  /// maximum une fois toutes les 15 secondes (le chauffeur émet sa position
  /// toutes les 5s, recalculer un itinéraire à chaque fois consommerait le
  /// quota Directions API pour rien).
  void _maybeRecomputeRoute() {
    final now = DateTime.now();
    if (_lastRouteRecompute != null && now.difference(_lastRouteRecompute!) < _routeRecomputeMinInterval) {
      return;
    }
    _lastRouteRecompute = now;
    _fetchDriverRoute();
  }

  Future<void> _fetchDriverRoute() async {
    if (_driverPosition == null || widget.draft.destLat == null) return;
    final result = await DirectionsService.getRoute(
      originLat: _driverPosition!.latitude,
      originLng: _driverPosition!.longitude,
      destLat: widget.draft.destLat!,
      destLng: widget.draft.destLng!,
    );
    if (!mounted || result['success'] != true) return;
    final route = result['result'] as DirectionsResult;
    setState(() => _routePoints = route.points);
  }

  String? get _connectionMessage {
    if (_driverId == null || _driverId!.isEmpty) return "Recherche d'un $_driverWord...";
    if (!_isDriverLive) return "Connexion au $_driverWord...";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ride = _ride;
    final driverName = ride?['driver']?['name']?.toString() ?? "Recherche d'un $_driverWord...";
    final driverRating = ride?['driver']?['rating']?.toString() ?? '-';
    final vehicle = ride?['driver']?['vehicle']?.toString() ?? '';
    final status = ride?['status']?.toString() ?? 'pending';

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
                child: Stack(
                  children: [
                    GoogleMap(
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
                        if (_driverPosition != null && _isDriverLive)
                          Marker(
                            markerId: const MarkerId('driver'),
                            position: _driverPosition!,
                            icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                            anchor: const Offset(0.5, 0.5),
                            flat: true,
                            rotation: _carIcon != null ? 0 : (_driverHeading ?? 0),
                          ),
                      },
                      polylines: {
                        if (_routePoints != null && _isDriverLive)
                          Polyline(
                            polylineId: const PolylineId('driver_route'),
                            points: _routePoints!,
                            color: _orange,
                            width: 4,
                          ),
                      },
                    ),
                    if (_connectionMessage != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: _orange),
                              ),
                              const SizedBox(width: 10),
                              Text(_connectionMessage!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                  ],
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
                    title: Text(
                      _isDelivery ? "Détails de la livraison" : "Détails de la course",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
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
                          if (_isDelivery) ...[
                            _detailRow("Destinataire", widget.draft.recipientName ?? '—'),
                            _detailRow("Téléphone", widget.draft.recipientPhone ?? '—'),
                            if (widget.draft.packageType?.isNotEmpty == true)
                              _detailRow("Colis", widget.draft.packageType!),
                          ],
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