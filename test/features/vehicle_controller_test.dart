import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vms_frontend/core/network/api_exception.dart';
import 'package:vms_frontend/features/vehicles/vehicle_controller.dart';
import 'package:vms_frontend/models/vehicle.dart';

import '../support/fake_vehicle_repository.dart';

const input = VehicleInput(
  vehicleNumber: 'ZZ 1',
  company: 'Acme',
  type: 'Van',
  brand: 'Ford',
  model: 'Transit',
  status: VehicleStatus.active,
);

void main() {
  test('starts loading, then shows data', () async {
    final repo = FakeVehicleRepository([sampleVehicle()])
      ..fetchGate = Completer<void>();
    final controller = VehicleController(repo)..ensureLoaded();

    expect(controller.phase, VehicleListPhase.loading);

    repo.fetchGate!.complete();
    await pumpEventQueue();

    expect(controller.phase, VehicleListPhase.ready);
    expect(controller.vehicles, hasLength(1));
    expect(controller.error, isNull);
  });

  test('ensureLoaded only fetches once', () async {
    final repo = FakeVehicleRepository();
    final controller = VehicleController(repo);

    controller
      ..ensureLoaded()
      ..ensureLoaded();
    await pumpEventQueue();

    expect(repo.fetchCalls, 1);
  });

  test(
    'first-load failure is a failed phase with a message, and retry recovers',
    () async {
      final repo = FakeVehicleRepository([sampleVehicle()])
        ..fetchError = networkDown;
      final controller = VehicleController(repo);

      await controller.load();
      expect(controller.phase, VehicleListPhase.failed);
      expect(controller.error, networkDown.message);

      repo.fetchError = null;
      await controller.load();
      expect(controller.phase, VehicleListPhase.ready);
      expect(controller.error, isNull);
      expect(controller.vehicles, hasLength(1));
    },
  );

  test('a failed refresh keeps showing the last good data', () async {
    final repo = FakeVehicleRepository([sampleVehicle()]);
    final controller = VehicleController(repo);
    await controller.load();

    repo.fetchError = networkDown;
    await controller.load();

    expect(controller.phase, VehicleListPhase.ready);
    expect(controller.vehicles, hasLength(1));
    expect(controller.error, networkDown.message);
  });

  test('create appends the server-saved vehicle', () async {
    final controller = VehicleController(FakeVehicleRepository());
    await controller.load();

    final saved = await controller.create(input);

    expect(controller.vehicles.single.id, saved.id);
    expect(controller.vehicles.single.vehicleNumber, 'ZZ 1');
  });

  test('a rejected create leaves the list unchanged and rethrows', () async {
    final repo = FakeVehicleRepository()
      ..createError = const ApiException(
        kind: ApiErrorKind.conflict,
        message: 'duplicate',
      );
    final controller = VehicleController(repo);
    await controller.load();

    await expectLater(controller.create(input), throwsA(isA<ApiException>()));
    expect(controller.vehicles, isEmpty);
  });

  test('update replaces the vehicle with the server response', () async {
    final controller = VehicleController(
      FakeVehicleRepository([sampleVehicle(id: 4)]),
    );
    await controller.load();

    await controller.update(4, input);

    expect(controller.vehicles.single.vehicleNumber, 'ZZ 1');
    expect(controller.vehicles.single.id, 4);
  });

  test('delete removes the vehicle only after the server confirms', () async {
    final repo = FakeVehicleRepository([
      sampleVehicle(id: 1),
      sampleVehicle(id: 2, number: 'B 2'),
    ]);
    final controller = VehicleController(repo);
    await controller.load();

    repo.deleteError = networkDown;
    await expectLater(
      controller.delete(controller.vehicles.first),
      throwsA(isA<ApiException>()),
    );
    expect(controller.vehicles, hasLength(2));

    repo.deleteError = null;
    await controller.delete(controller.vehicles.first);
    expect(controller.vehicles.map((v) => v.id), [2]);
  });

  test(
    'deleting something already gone on the server just drops it locally',
    () async {
      final repo = FakeVehicleRepository([sampleVehicle()]);
      final controller = VehicleController(repo);
      await controller.load();
      repo.deleteError = const ApiException(
        kind: ApiErrorKind.notFound,
        message: 'gone',
      );

      await controller.delete(controller.vehicles.single);

      expect(controller.vehicles, isEmpty);
    },
  );

  test(
    'delete keeps the vehicle in the list until the server confirms',
    () async {
      final repo = FakeVehicleRepository([sampleVehicle(id: 1)])
        ..deleteGate = Completer<void>();
      final controller = VehicleController(repo);
      await controller.load();

      final deletion = controller.delete(controller.vehicles.single);
      await pumpEventQueue();

      expect(
        controller.vehicles,
        hasLength(1),
        reason: 'request still in flight',
      );
      expect(repo.deleteCalls, 1);

      repo.deleteGate!.complete();
      await deletion;
      expect(controller.vehicles, isEmpty);
    },
  );

  test('beforeRemoval runs only after the server succeeded, and before the list changes', () async {
    final repo = FakeVehicleRepository([sampleVehicle(id: 1)]);
    final controller = VehicleController(repo);
    await controller.load();
    final seen = <String>[];

    await controller.delete(
      controller.vehicles.single,
      beforeRemoval: () async =>
          seen.add('hook sees ${controller.vehicles.length} vehicle(s)'),
    );

    expect(seen, ['hook sees 1 vehicle(s)']);
    expect(controller.vehicles, isEmpty);
  });

  test('beforeRemoval is skipped when the server refuses', () async {
    final repo = FakeVehicleRepository([sampleVehicle(id: 1)])
      ..deleteError = networkDown;
    final controller = VehicleController(repo);
    await controller.load();
    var hookRan = false;

    await expectLater(
      controller.delete(
        controller.vehicles.single,
        beforeRemoval: () async => hookRan = true,
      ),
      throwsA(isA<ApiException>()),
    );

    expect(hookRan, isFalse);
    expect(controller.vehicles, hasLength(1));
  });

  group('after a timeout the outcome is unknown, so the list is re-read', () {
    const timeout = ApiException(
      kind: ApiErrorKind.timeout,
      message: 'too slow',
    );

    test(
      'a delete that timed out but was applied disappears from the list',
      () async {
        final repo = FakeVehicleRepository([sampleVehicle(id: 1)])
          ..deleteError = timeout
          ..applyDeleteDespiteError = true;
        final controller = VehicleController(repo);
        await controller.load();

        await expectLater(
          controller.delete(controller.vehicles.single),
          throwsA(isA<ApiException>()),
        );
        await pumpEventQueue();

        expect(
          controller.vehicles,
          isEmpty,
          reason: 'the server did delete it',
        );
        expect(repo.fetchCalls, 2);
      },
    );

    test(
      'a delete that timed out and was NOT applied keeps the vehicle',
      () async {
        final repo = FakeVehicleRepository([sampleVehicle(id: 1)])
          ..deleteError = timeout;
        final controller = VehicleController(repo);
        await controller.load();

        await expectLater(
          controller.delete(controller.vehicles.single),
          throwsA(isA<ApiException>()),
        );
        await pumpEventQueue();

        expect(controller.vehicles, hasLength(1));
      },
    );

    test('a create or update that timed out triggers a re-read too', () async {
      final repo = FakeVehicleRepository([sampleVehicle(id: 1)])
        ..createError = timeout;
      final controller = VehicleController(repo);
      await controller.load();

      await expectLater(controller.create(input), throwsA(isA<ApiException>()));
      await pumpEventQueue();
      expect(repo.fetchCalls, 2);

      repo.updateError = timeout;
      await expectLater(
        controller.update(1, input),
        throwsA(isA<ApiException>()),
      );
      await pumpEventQueue();
      expect(repo.fetchCalls, 3);
    });

    test('ordinary failures do not cause extra reads', () async {
      final repo = FakeVehicleRepository([sampleVehicle(id: 1)])
        ..deleteError = networkDown;
      final controller = VehicleController(repo);
      await controller.load();

      await expectLater(
        controller.delete(controller.vehicles.single),
        throwsA(isA<ApiException>()),
      );
      await pumpEventQueue();

      expect(repo.fetchCalls, 1);
    });
  });
}
