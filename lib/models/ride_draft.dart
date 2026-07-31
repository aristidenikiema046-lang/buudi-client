/// Regroupe les informations saisies pendant les 3 étapes du flux VTC
/// (Course Taxi -> Confirmation -> Suivi), avant l'appel à POST /v1/client/rides.
class RideDraft {
  double pickupLat;
  double pickupLng;
  String pickupAddress;

  double? destLat;
  double? destLng;
  String destAddress;

  String serviceType; // ok_taxi | ok_confort | ok_van
  double distanceKm;
  int durationMin;
  double price;

  String paymentMethod; // wallet | mobile_money | card | cash

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
  });

  bool get hasDestination => destLat != null && destLng != null;
}

class ServiceTypeOption {
  final String value;
  final String label;
  final double perKmRate;

  const ServiceTypeOption({required this.value, required this.label, required this.perKmRate});
}

const List<ServiceTypeOption> kServiceTypes = [
  ServiceTypeOption(value: 'ok_taxi', label: 'OK Taxi', perKmRate: 160),
  ServiceTypeOption(value: 'ok_confort', label: 'OK Confort', perKmRate: 280),
  ServiceTypeOption(value: 'ok_van', label: 'OK Van', perKmRate: 400),
];
