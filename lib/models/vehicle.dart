/// Mirrors the backend's `VehicleStatus` (ACTIVE, INACTIVE, UNDER_MAINTENANCE).
enum VehicleStatus {
  active('Active'),
  inactive('Inactive'),
  underMaintenance('Under maintenance');

  const VehicleStatus(this.label);
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

  final int id;
  final String vehicleNumber;
  final String company;
  final String type;
  final String brand;
  final String model;
  final VehicleStatus status;

  String get displayName => '$brand $model';
}

/// The editable fields of a vehicle, used for both create and update.
class VehicleInput {
  const VehicleInput({
    required this.vehicleNumber,
    required this.company,
    required this.type,
    required this.brand,
    required this.model,
    required this.status,
  });

  final String vehicleNumber;
  final String company;
  final String type;
  final String brand;
  final String model;
  final VehicleStatus status;
}
