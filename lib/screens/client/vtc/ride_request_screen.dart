import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/ride_draft.dart';
import '../../../utils/formatters.dart';
import 'destination_search_screen.dart';
import 'ride_confirmation_screen.dart';

/// Étape 1 du flux VTC : "Course Taxi".
///
/// NOTE : le tracé affiché sur la carte est une ligne droite entre le départ
/// et la destination (Polyline simple), pas un itinéraire routier réel — ça
/// demanderait l'API Directions de Google (facturée séparément, hors
/// périmètre Phase A). Idem pour la distance/durée : calculées à vol d'oiseau
/// (formule haversine via Geolocator) + une vitesse moyenne urbaine estimée,
/// pas un vrai temps de trajet routier.
class RideRequestScreen extends StatefulWidget {
  const RideRequestScreen({Key? key}) : super(key: key);

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  static const _orange = Color(0xFFFF5722);

  GoogleMapController? _mapController;
  LatLng? _pickup;
  String _pickupAddress = 'Localisation en cours...';
  bool _loadingLocation = true;
  String? _locationError;

  DestinationResult? _destination;
  String _serviceType = 'ok_taxi';
  final Geocoding _geocoding = Geocoding();

  final List<Map<String, String>> _quickPlaces = const [
    {'label': 'Maison', 'sub': 'Cocody Riviera', 'query': "Cocody Riviera, Abidjan, Côte d'Ivoire"},
    {'label': 'Travail', 'sub': 'Plateau', 'query': "Plateau, Abidjan, Côte d'Ivoire"},
    {'label': 'Hotel Capitol', 'sub': 'Riviera Golf', 'query': "Riviera Golf, Abidjan, Côte d'Ivoire"},
  ];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    setState(() => _loadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _loadingLocation = false;
          _locationError = "Le GPS est désactivé sur votre téléphone.";
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _loadingLocation = false;
          _locationError = "Autorisation de localisation refusée.";
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      String address = "Position actuelle";
      try {
        final placemarks = await _geocoding.placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          address = [p.name, p.subLocality, p.locality].where((e) => e != null && e.isNotEmpty).join(', ');
        }
      } catch (_) {
        // On garde "Position actuelle" si le reverse-geocoding échoue.
      }

      if (!mounted) return;
      setState(() {
        _pickup = LatLng(position.latitude, position.longitude);
        _pickupAddress = address.isEmpty ? "Position actuelle" : address;
        _loadingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _locationError = "Impossible d'obtenir votre position.";
      });
    }
  }

  Future<void> _pickDestination() async {
    final result = await Navigator.push<DestinationResult>(
      context,
      MaterialPageRoute(builder: (_) => const DestinationSearchScreen()),
    );
    if (result != null) {
      setState(() => _destination = result);
      _fitMapToRoute();
    }
  }

  Future<void> _quickPickDestination(String query) async {
    try {
      final locations = await _geocoding.locationFromAddress(query);
      if (locations.isEmpty) return;
      final loc = locations.first;
      setState(() => _destination = DestinationResult(lat: loc.latitude, lng: loc.longitude, address: query));
      _fitMapToRoute();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Adresse introuvable.")),
        );
      }
    }
  }

  void _fitMapToRoute() {
    if (_mapController == null || _pickup == null || _destination == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        _pickup!.latitude < _destination!.lat ? _pickup!.latitude : _destination!.lat,
        _pickup!.longitude < _destination!.lng ? _pickup!.longitude : _destination!.lng,
      ),
      northeast: LatLng(
        _pickup!.latitude > _destination!.lat ? _pickup!.latitude : _destination!.lat,
        _pickup!.longitude > _destination!.lng ? _pickup!.longitude : _destination!.lng,
      ),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  double get _distanceKm {
    if (_pickup == null || _destination == null) return 0;
    final meters = Geolocator.distanceBetween(
      _pickup!.latitude,
      _pickup!.longitude,
      _destination!.lat,
      _destination!.lng,
    );
    return meters / 1000;
  }

  int get _durationMin {
    const avgSpeedKmH = 35;
    final min = (_distanceKm / avgSpeedKmH) * 60;
    return min < 1 ? 1 : min.round();
  }

  double _priceFor(ServiceTypeOption option) {
    final price = option.perKmRate * (_distanceKm == 0 ? 1 : _distanceKm);
    return (price / 50).round() * 50;
  }

  void _goToConfirmation() {
    if (_pickup == null || _destination == null) return;
    final selected = kServiceTypes.firstWhere((o) => o.value == _serviceType);
    final draft = RideDraft(
      pickupLat: _pickup!.latitude,
      pickupLng: _pickup!.longitude,
      pickupAddress: _pickupAddress,
      destLat: _destination!.lat,
      destLng: _destination!.lng,
      destAddress: _destination!.address,
      serviceType: _serviceType,
      distanceKm: _distanceKm,
      durationMin: _durationMin,
      price: _priceFor(selected),
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => RideConfirmationScreen(draft: draft)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Course Taxi", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.history_rounded, color: Colors.black))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _loadingLocation
                              ? "Localisation en cours..."
                              : (_locationError ?? _pickupAddress),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  GestureDetector(
                    onTap: _pickDestination,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: _orange, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _destination?.address ?? "Où allez-vous ?",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: _destination == null ? Colors.grey[500] : Colors.black87,
                            ),
                          ),
                        ),
                        const Icon(Icons.add_circle_outline_rounded, color: _orange, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _quickPlaces.map((place) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.star_rounded, size: 14, color: _orange),
                    label: Text(place['label']!, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.white,
                    onPressed: () => _quickPickDestination(place['query']!),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _loadingLocation
                    ? Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(color: _orange)))
                    : _pickup == null
                        ? Container(
                            color: Colors.grey[200],
                            child: Center(child: Text(_locationError ?? "Position indisponible")),
                          )
                        : GoogleMap(
                            initialCameraPosition: CameraPosition(target: _pickup!, zoom: 14),
                            onMapCreated: (c) => _mapController = c,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            markers: {
                              Marker(markerId: const MarkerId('pickup'), position: _pickup!, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
                              if (_destination != null)
                                Marker(
                                  markerId: const MarkerId('destination'),
                                  position: LatLng(_destination!.lat, _destination!.lng),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                                ),
                            },
                            polylines: {
                              if (_destination != null)
                                Polyline(
                                  polylineId: const PolylineId('route'),
                                  color: _orange,
                                  width: 4,
                                  points: [_pickup!, LatLng(_destination!.lat, _destination!.lng)],
                                ),
                            },
                          ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("Type de service", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: kServiceTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final option = kServiceTypes[index];
                final isSelected = _serviceType == option.value;
                return GestureDetector(
                  onTap: () => setState(() => _serviceType = option.value),
                  child: Container(
                    width: 100,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFFF0EE) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSelected ? _orange : Colors.transparent, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.directions_car_filled_rounded, size: 22, color: Colors.black87),
                        Text(option.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(
                          _destination == null ? '--' : formatCfa(_priceFor(option)),
                          style: const TextStyle(fontSize: 11, color: _orange, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: ElevatedButton(
              onPressed: (_pickup != null && _destination != null) ? _goToConfirmation : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                disabledBackgroundColor: Colors.grey[300],
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text("Voir le prix", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
