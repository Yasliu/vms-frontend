enum VehicleStatus {
  available('Available'),
  inUse('In use'),
  maintenance('Maintenance'),
  retired('Retired');

  const VehicleStatus(this.label);
  final String label;
}

enum VehicleType {
  car('Car'),
  van('Van'),
  truck('Truck'),
  trailer('Trailer'),
  forklift('Forklift');

  const VehicleType(this.label);
  final String label;
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.vehicleNumber,
    required this.company,
    required this.type,
    required this.brand,
    required this.model,
    required this.status,
  });

  final String id;
  final String vehicleNumber;
  final String company;
  final VehicleType type;
  final String brand;
  final String model;
  final VehicleStatus status;

  String get displayName => '$brand $model';
}
