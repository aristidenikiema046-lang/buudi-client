import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

/// Résultat renvoyé à l'écran appelant : coordonnées + adresse lisible.
class DestinationResult {
  final double lat;
  final double lng;
  final String address;

  DestinationResult({required this.lat, required this.lng, required this.address});
}

/// Écran de recherche d'adresse (étape 1 du flux VTC, champ "Où allez-vous ?").
/// Utilise le géocodage natif (geocoding) : pas de suggestions "autocomplete"
/// façon Google Places (nécessiterait l'API Places, hors périmètre Phase A).
class DestinationSearchScreen extends StatefulWidget {
  const DestinationSearchScreen({Key? key}) : super(key: key);

  @override
  State<DestinationSearchScreen> createState() => _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  static const _orange = Color(0xFFFF5722);

  final TextEditingController _controller = TextEditingController();
  final Geocoding _geocoding = Geocoding();
  bool _searching = false;
  String? _error;
  List<DestinationResult> _results = [];

  final List<Map<String, String>> _quickPlaces = const [
    {'label': 'Maison', 'sub': 'Cocody Riviera', 'query': 'Cocody Riviera, Abidjan, Côte d\'Ivoire'},
    {'label': 'Travail', 'sub': 'Plateau', 'query': 'Plateau, Abidjan, Côte d\'Ivoire'},
    {'label': 'Hotel Capitol', 'sub': 'Riviera Golf', 'query': 'Riviera Golf, Abidjan, Côte d\'Ivoire'},
  ];

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
      _results = [];
    });
    try {
      final locations = await _geocoding.locationFromAddress(query);
      final results = <DestinationResult>[];
      for (final loc in locations.take(5)) {
        String address = query;
        try {
          final placemarks = await _geocoding.placemarkFromCoordinates(loc.latitude, loc.longitude);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            address = [p.name, p.subLocality, p.locality, p.country]
                .where((e) => e != null && e.isNotEmpty)
                .join(', ');
          }
        } catch (_) {
          // On garde la requête brute comme adresse si le reverse-geocoding échoue.
        }
        results.add(DestinationResult(lat: loc.latitude, lng: loc.longitude, address: address));
      }
      setState(() {
        _searching = false;
        _results = results;
        if (results.isEmpty) _error = "Aucune adresse trouvée.";
      });
    } catch (e) {
      setState(() {
        _searching = false;
        _error = "Impossible de trouver cette adresse. Vérifiez l'orthographe ou votre connexion.";
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Où allez-vous ?", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: "Entrez une adresse ou un lieu",
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: () => _search(_controller.text),
                ),
                filled: true,
                fillColor: const Color(0xFFF7F7F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            if (_controller.text.isEmpty && _results.isEmpty) ...[
              Text("Suggestions", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[600])),
              const SizedBox(height: 8),
              ..._quickPlaces.map((place) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined, color: _orange),
                    title: Text(place['label']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(place['sub']!),
                    onTap: () {
                      _controller.text = place['query']!;
                      _search(place['query']!);
                    },
                  )),
            ],
            if (_searching) const Padding(padding: EdgeInsets.only(top: 20), child: Center(child: CircularProgressIndicator(color: _orange))),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final r = _results[index];
                  return ListTile(
                    leading: const Icon(Icons.place_rounded, color: _orange),
                    title: Text(r.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(context, r),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
