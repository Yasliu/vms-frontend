import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
import '../../data/vehicle_repository.dart';
import '../../models/vehicle.dart';

enum VehicleListPhase { loading, ready, failed }

/// Holds the vehicle list and its loading/error state for the UI. Widgets call
/// these methods and listen for changes; they never see HTTP.
class VehicleController extends ChangeNotifier {
  VehicleController(this._repository);

  final VehicleRepository _repository;

  VehicleListPhase _phase = VehicleListPhase.loading;
  List<Vehicle> _vehicles = const [];
  String? _error;
  bool _refreshing = false;
  bool _started = false;
  bool _disposed = false;

  VehicleListPhase get phase => _phase;
  List<Vehicle> get vehicles => _vehicles;

  /// Why the list could not be loaded (when [phase] is `failed`) or refreshed
  /// (when stale data is still being shown).
  String? get error => _error;
  bool get isRefreshing => _refreshing;

  /// Forgets everything, for example on sign-out, so the next user starts
  /// clean and never sees the previous user's data.
  void reset() {
    _vehicles = const [];
    _phase = VehicleListPhase.loading;
    _error = null;
    _started = false;
    notifyListeners();
  }

  /// Loads the list once; later calls do nothing. Use [load] to refresh.
  void ensureLoaded() {
    if (_started) return;
    _started = true;
    load();
  }

  Future<void> load() async {
    if (_refreshing) return;
    final hadData = _phase == VehicleListPhase.ready;
    _refreshing = true;
    if (!hadData) _phase = VehicleListPhase.loading;
    _error = null;
    notifyListeners();

    try {
      _vehicles = await _repository.fetchAll();
      _phase = VehicleListPhase.ready;
    } on ApiException catch (e) {
      _error = e.message;
      // Keep showing the last good data if we have it.
      _phase = hadData ? VehicleListPhase.ready : VehicleListPhase.failed;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  /// Throws [ApiException] so the form can show field-level errors.
  Future<Vehicle> create(VehicleInput input) async {
    final Vehicle created;
    try {
      created = await _repository.create(input);
    } on ApiException catch (e) {
      _reconcileIfOutcomeUnknown(e);
      rethrow;
    }
    _vehicles = [..._vehicles, created];
    _phase = VehicleListPhase.ready;
    notifyListeners();
    return created;
  }

  Future<Vehicle> update(int id, VehicleInput input) async {
    final Vehicle updated;
    try {
      updated = await _repository.update(id, input);
    } on ApiException catch (e) {
      _reconcileIfOutcomeUnknown(e);
      rethrow;
    }
    _vehicles = [for (final v in _vehicles) v.id == id ? updated : v];
    notifyListeners();
    return updated;
  }

  /// Deletes on the server first; the vehicle leaves the list only after the
  /// server confirms. [beforeRemoval] runs between the two (the screen plays its
  /// collapse animation there). If the server refuses, the list is untouched and
  /// the [ApiException] is rethrown.
  Future<void> delete(
    Vehicle vehicle, {
    Future<void> Function()? beforeRemoval,
  }) async {
    try {
      await _repository.delete(vehicle.id);
    } on ApiException catch (e) {
      // Already gone on the server: the list was stale, so drop it locally.
      if (e.kind != ApiErrorKind.notFound) {
        _reconcileIfOutcomeUnknown(e);
        rethrow;
      }
    }
    await beforeRemoval?.call();
    _vehicles = _vehicles.where((v) => v.id != vehicle.id).toList();
    notifyListeners();
  }

  /// A timeout means the server may or may not have applied the change, so the
  /// list on screen could now be wrong. Re-read it so screen and database agree.
  void _reconcileIfOutcomeUnknown(ApiException e) {
    if (e.kind == ApiErrorKind.timeout) unawaited(load());
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
