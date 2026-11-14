import 'package:flutter/foundation.dart';

import '../models/vehicle.dart';
import 'mock_vehicles.dart';

/// In-memory store that stands in for a backend until an API exists.
class VehicleRepository {
  VehicleRepository._();

  static final VehicleRepository instance = VehicleRepository._();

  final ValueNotifier<List<Vehicle>> vehicles = ValueNotifier<List<Vehicle>>(
    List<Vehicle>.of(mockVehicles),
  );

  int _counter = mockVehicles.length;

  String nextId() {
    _counter++;
    return 'V-${_counter.toString().padLeft(3, '0')}';
  }

  bool isNumberTaken(String number, {String? exceptId}) {
    final wanted = number.trim().toUpperCase();
    return vehicles.value.any(
      (v) => v.id != exceptId && v.vehicleNumber.toUpperCase() == wanted,
    );
  }

  void add(Vehicle vehicle) {
    vehicles.value = [...vehicles.value, vehicle];
  }

  void update(Vehicle vehicle) {
    vehicles.value = [
      for (final v in vehicles.value) v.id == vehicle.id ? vehicle : v,
    ];
  }

  void remove(String id) {
    vehicles.value = vehicles.value.where((v) => v.id != id).toList();
  }
}
