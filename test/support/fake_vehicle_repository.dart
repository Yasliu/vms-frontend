import 'dart:async';

import 'package:vms_frontend/core/network/api_exception.dart';
import 'package:vms_frontend/data/vehicle_repository.dart';
import 'package:vms_frontend/models/vehicle.dart';

Vehicle sampleVehicle({
  int id = 1,
  String number = 'AB 12345',
  String company = 'Acme Logistics',
  String type = 'Truck',
  String brand = 'Volvo',
  String model = 'FH16',
  VehicleStatus status = VehicleStatus.active,
}) => Vehicle(
  id: id,
  vehicleNumber: number,
  company: company,
  type: type,
  brand: brand,
  model: model,
  status: status,
);

const networkDown = ApiException(
  kind: ApiErrorKind.network,
  message: 'Cannot reach the server. Check your connection and try again.',
);

/// In-memory stand-in for the backend that can be told to fail or to wait.
class FakeVehicleRepository implements VehicleRepository {
  FakeVehicleRepository([List<Vehicle> seed = const []])
    : vehicles = List.of(seed);

  final List<Vehicle> vehicles;
  int _nextId = 100;

  /// While set, [fetchAll] waits for it to complete.
  Completer<void>? fetchGate;
  ApiException? fetchError;
  ApiException? createError;
  ApiException? updateError;
  ApiException? deleteError;

  /// While set, [delete] waits for it to complete (a request "in flight").
  Completer<void>? deleteGate;
  int deleteCalls = 0;

  /// Simulates a request that times out on the client but is still applied by
  /// the server afterwards.
  bool applyDeleteDespiteError = false;
  int fetchCalls = 0;
  final List<VehicleInput> created = [];

  @override
  Future<List<Vehicle>> fetchAll() async {
    fetchCalls++;
    if (fetchGate != null) await fetchGate!.future;
    if (fetchError != null) throw fetchError!;
    return List.of(vehicles);
  }

  @override
  Future<Vehicle> create(VehicleInput input) async {
    if (createError != null) throw createError!;
    created.add(input);
    final vehicle = _from(_nextId++, input);
    vehicles.add(vehicle);
    return vehicle;
  }

  @override
  Future<Vehicle> update(int id, VehicleInput input) async {
    if (updateError != null) throw updateError!;
    final vehicle = _from(id, input);
    final index = vehicles.indexWhere((v) => v.id == id);
    vehicles[index] = vehicle;
    return vehicle;
  }

  @override
  Future<void> delete(int id) async {
    deleteCalls++;
    if (deleteGate != null) await deleteGate!.future;
    if (deleteError != null) {
      if (applyDeleteDespiteError) vehicles.removeWhere((v) => v.id == id);
      throw deleteError!;
    }
    vehicles.removeWhere((v) => v.id == id);
  }

  // Like the real server: trim, collapse spacing, upper-case the number.
  static String _normalize(String number) =>
      number.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

  Vehicle _from(int id, VehicleInput i) => Vehicle(
    id: id,
    vehicleNumber: _normalize(i.vehicleNumber),
    company: i.company,
    type: i.type,
    brand: i.brand,
    model: i.model,
    status: i.status,
  );
}
