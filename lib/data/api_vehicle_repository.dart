import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/vehicle.dart';
import 'vehicle_error_mapper.dart';
import 'vehicle_repository.dart';

/// Talks to the Spring Boot backend:
///
///     POST   /api/v1/vehicles
///     GET    /api/v1/vehicles?page=&size=
///     PUT    /api/v1/vehicles/{id}
///     DELETE /api/v1/vehicles/{id}
class ApiVehicleRepository implements VehicleRepository {
  ApiVehicleRepository(this._api);

  final ApiClient _api;

  static const _path = '/api/v1/vehicles';

  /// The backend caps page size at 100.
  static const _pageSize = 100;

  @override
  Future<List<Vehicle>> fetchAll() async {
    final vehicles = <Vehicle>[];
    var page = 0;
    while (true) {
      final json = await _api.get(
        _path,
        query: {'page': '$page', 'size': '$_pageSize'},
      );
      final map = _asMap(json);
      final content = map['content'];
      final totalPages = map['totalPages'];
      if (content is! List || totalPages is! int) throw _unreadable();

      vehicles.addAll(content.map((e) => _vehicleFrom(_asMap(e))));
      page++;
      if (content.isEmpty || page >= totalPages) return vehicles;
    }
  }

  @override
  Future<Vehicle> create(VehicleInput input) async {
    try {
      return _vehicleFrom(_asMap(await _api.post(_path, _bodyFrom(input))));
    } on ApiException catch (e) {
      throw VehicleErrorMapper.forSave(e);
    }
  }

  @override
  Future<Vehicle> update(int id, VehicleInput input) async {
    try {
      return _vehicleFrom(
        _asMap(await _api.put('$_path/$id', _bodyFrom(input))),
      );
    } on ApiException catch (e) {
      throw VehicleErrorMapper.forSave(e);
    }
  }

  @override
  Future<void> delete(int id) async {
    await _api.delete('$_path/$id');
  }

  Map<String, Object?> _bodyFrom(VehicleInput input) => {
    'vehicleNumber': input.vehicleNumber,
    'company': input.company,
    'type': input.type,
    'brand': input.brand,
    'model': input.model,
    'status': _statusToApi(input.status),
  };

  Vehicle _vehicleFrom(Map<String, Object?> json) {
    final id = json['id'];
    final status = json['status'];
    final number = json['vehicleNumber'];
    final company = json['company'];
    final type = json['type'];
    final brand = json['brand'];
    final model = json['model'];
    if (id is! int ||
        status is! String ||
        number is! String ||
        company is! String ||
        type is! String ||
        brand is! String ||
        model is! String) {
      throw _unreadable();
    }
    return Vehicle(
      id: id,
      vehicleNumber: number,
      company: company,
      type: type,
      brand: brand,
      model: model,
      status: _statusFromApi(status),
    );
  }

  VehicleStatus _statusFromApi(String value) => switch (value) {
    'ACTIVE' => VehicleStatus.active,
    'INACTIVE' => VehicleStatus.inactive,
    'UNDER_MAINTENANCE' => VehicleStatus.underMaintenance,
    _ => throw _unreadable(),
  };

  String _statusToApi(VehicleStatus status) => switch (status) {
    VehicleStatus.active => 'ACTIVE',
    VehicleStatus.inactive => 'INACTIVE',
    VehicleStatus.underMaintenance => 'UNDER_MAINTENANCE',
  };

  Map<String, Object?> _asMap(Object? json) {
    if (json is Map<String, Object?>) return json;
    throw _unreadable();
  }

  ApiException _unreadable() => const ApiException(
    kind: ApiErrorKind.unexpected,
    message: 'The server sent data the app could not understand.',
  );
}
