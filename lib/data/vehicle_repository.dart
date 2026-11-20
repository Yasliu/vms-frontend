import '../models/vehicle.dart';

/// Everything the app can do with vehicles. Implementations throw
/// `ApiException` on failure and never expose transport details.
abstract class VehicleRepository {
  Future<List<Vehicle>> fetchAll();

  Future<Vehicle> create(VehicleInput input);

  Future<Vehicle> update(int id, VehicleInput input);

  Future<void> delete(int id);
}
