/// Regroupe les informations saisies pendant les 3 étapes du flux VTC
/// (Course Taxi -> Confirmation -> Suivi), avant l'appel à POST /v1/client/rides.
class RideDraft {
  double pickupLat;
  double pickupLng;
  String pickupAddress;

  double? destLat;
  double? destLng;
  String destAddress;

  String serviceType; // ok_taxi | ok_confort | ok_van | delivery
  double distanceKm;
  int durationMin;
  double price;

  String paymentMethod; // wallet | mobile_money | card | cash

  // Uniquement pertinents quand serviceType == 'delivery'.
  String? recipientName;
  String? recipientPhone;
  String? packageType;
  double? packageWeightKg;
  String? deliveryInstructions;

  RideDraft({
    required this.pickupLat,
    required this.pickupLng,
    this.pickupAddress = '',
    this.destLat,
    this.destLng,
    this.destAddress = '',
    this.serviceType = 'ok_taxi',
    this.distanceKm = 0,
    this.durationMin = 0,
    this.price = 0,
    this.paymentMethod = 'wallet',
    this.recipientName,
    this.recipientPhone,
    this.packageType,
    this.packageWeightKg,
    this.deliveryInstructions,
  });

  bool get hasDestination => destLat != null && destLng != null;
  bool get isDelivery => serviceType == 'delivery';
}

class ServiceTypeOption {
  final String value;
  // Valeur exacte attendue par le validator Laravel pour 'service_type' (ne pas renommer sans
  // mettre à jour le backend en parallèle) — voir RideService._backendServiceType.
  final String label;
  // Libellé affiché à l'utilisateur (marque BUUDI), indépendant de la valeur envoyée à l'API.
  final String displayLabel;
  final double perKmRate;

  const ServiceTypeOption({
    required this.value,
    required this.label,
    required this.displayLabel,
    required this.perKmRate,
  });
}

const List<ServiceTypeOption> kServiceTypes = [
  ServiceTypeOption(value: 'ok_taxi', label: 'OK Taxi', displayLabel: 'BUUDI Taxi', perKmRate: 160),
  ServiceTypeOption(value: 'ok_confort', label: 'OK Confort', displayLabel: 'BUUDI Confort', perKmRate: 280),
  ServiceTypeOption(value: 'ok_van', label: 'OK Van', displayLabel: 'BUUDI Van', perKmRate: 400),
  ServiceTypeOption(value: 'delivery', label: 'Livraison', displayLabel: 'Livraison', perKmRate: 200),
];
