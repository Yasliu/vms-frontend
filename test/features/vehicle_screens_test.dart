import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vms_frontend/core/network/api_exception.dart';
import 'package:vms_frontend/models/vehicle.dart';

import '../support/fake_vehicle_repository.dart';
import '../support/test_app.dart';

Future<void> fillForm(WidgetTester tester, {String number = 'new 777'}) async {
  await tester.enterText(field('Vehicle number *'), number);
  await tester.enterText(field('Company *'), 'Stark Danmark');
  await tester.enterText(field('Type *'), 'Truck');
  await tester.enterText(field('Brand *'), 'Scania');
  await tester.enterText(field('Model *'), 'R450');
}

Future<void> submit(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  group('list states', () {
    testWidgets('shows a loading state until the server answers', (
      tester,
    ) async {
      final repo = FakeVehicleRepository([sampleVehicle()])
        ..fetchGate = Completer<void>();

      await openVehicles(tester, repo, settle: false);

      expect(find.text('Loading vehicles…'), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Loading vehicles…'),
            matching: find.byType(Card),
          ),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.text('AB 12345'), findsNothing);

      repo.fetchGate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('Loading vehicles…'), findsNothing);
      expect(find.text('AB 12345'), findsOneWidget);
    });

    testWidgets('shows the success state with real data and counts', (
      tester,
    ) async {
      final repo = FakeVehicleRepository([
        sampleVehicle(),
        sampleVehicle(
          id: 2,
          number: 'CD 67890',
          status: VehicleStatus.inactive,
        ),
        sampleVehicle(
          id: 3,
          number: 'EF 24680',
          status: VehicleStatus.underMaintenance,
        ),
      ]);

      await openVehicles(tester, repo);

      expect(find.text('AB 12345'), findsOneWidget);
      expect(find.text('CD 67890'), findsOneWidget);
      expect(find.text('EF 24680'), findsOneWidget);
      expect(find.text('Showing 3 of 3 vehicles'), findsOneWidget);
      expect(find.text('Under maintenance'), findsWidgets);
    });

    testWidgets('shows the empty state when there are no vehicles', (
      tester,
    ) async {
      await openVehicles(tester, FakeVehicleRepository());

      expect(find.text('No vehicles registered yet'), findsOneWidget);
      expect(find.text('Could not load vehicles'), findsNothing);
    });

    testWidgets('shows a friendly error with retry, and retry recovers', (
      tester,
    ) async {
      final repo = FakeVehicleRepository([sampleVehicle()])
        ..fetchError = networkDown;

      await openVehicles(tester, repo);

      expect(find.text('Could not load vehicles'), findsOneWidget);
      expect(find.text(networkDown.message), findsOneWidget);
      expect(find.text('AB 12345'), findsNothing);

      repo.fetchError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load vehicles'), findsNothing);
      expect(find.text('AB 12345'), findsOneWidget);
    });

    testWidgets('a failed refresh keeps the data and explains the problem', (
      tester,
    ) async {
      final repo = FakeVehicleRepository([sampleVehicle()]);
      await openVehicles(tester, repo);

      repo.fetchError = const ApiException(
        kind: ApiErrorKind.server,
        message: 'The server ran into a problem.',
      );
      await tester.tap(find.byTooltip('Refresh list'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not refresh the list'), findsOneWidget);
      expect(find.text('AB 12345'), findsOneWidget);
    });
  });

  group('delete', () {
    testWidgets('confirms, deletes on the server and shows success', (
      tester,
    ) async {
      final repo = FakeVehicleRepository([sampleVehicle()]);
      await openVehicles(tester, repo);

      await tester.tap(find.text('Delete').first);
      await tester.pumpAndSettle();
      expect(find.text('Delete this vehicle?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(repo.vehicles, isEmpty);
      expect(find.text('AB 12345 deleted'), findsOneWidget);
      expect(find.text('No vehicles registered yet'), findsOneWidget);
    });

    testWidgets('cancelling does not call the server', (tester) async {
      final repo = FakeVehicleRepository([sampleVehicle()]);
      await openVehicles(tester, repo);

      await tester.tap(find.text('Delete').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.vehicles, hasLength(1));
      expect(find.text('AB 12345'), findsOneWidget);
    });

    testWidgets('the row stays visible and busy until the server answers', (
      tester,
    ) async {
      final repo = FakeVehicleRepository([sampleVehicle()])
        ..deleteGate = Completer<void>();
      await openVehicles(tester, repo);

      await tester.tap(find.text('Delete').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(repo.deleteCalls, 1);
      expect(
        find.text('AB 12345'),
        findsOneWidget,
        reason: 'not removed before the server confirms',
      );
      expect(find.text('Deleting…'), findsOneWidget);
      expect(
        find.text('Showing 1 of 1 vehicles'),
        findsOneWidget,
        reason: 'counts do not change yet',
      );
      expect(find.text('AB 12345 deleted'), findsNothing);
      expect(
        find.text('Delete'),
        findsNothing,
        reason: 'no second delete while one is in flight',
      );

      repo.deleteGate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('AB 12345'), findsNothing);
      expect(find.text('AB 12345 deleted'), findsOneWidget);
      expect(find.text('No vehicles registered yet'), findsOneWidget);
    });

    testWidgets('a timeout is explained honestly and the list is re-read', (
      tester,
    ) async {
      final repo =
          FakeVehicleRepository([
              sampleVehicle(),
              sampleVehicle(id: 2, number: 'CD 67890'),
            ])
            ..deleteError = const ApiException(
              kind: ApiErrorKind.timeout,
              message: 'too slow',
            )
            ..applyDeleteDespiteError = true;
      await openVehicles(tester, repo);

      await tester.tap(find.text('Delete').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'No answer from the server while deleting AB 12345',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('refreshed with the latest data'),
        findsOneWidget,
      );
      expect(
        find.text('AB 12345'),
        findsNothing,
        reason: 'the server did delete it; the re-read shows that',
      );
      expect(find.text('CD 67890'), findsOneWidget);
    });

    testWidgets('a server failure brings the row back and shows the error', (
      tester,
    ) async {
      final repo = FakeVehicleRepository([sampleVehicle()])
        ..deleteError = networkDown;
      await openVehicles(tester, repo);

      await tester.tap(find.text('Delete').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not delete AB 12345'), findsOneWidget);
      expect(find.textContaining(networkDown.message), findsOneWidget);
      expect(find.text('AB 12345'), findsOneWidget);
      expect(repo.vehicles, hasLength(1));
    });
  });

  group('create', () {
    testWidgets('sends the form to the server and the new vehicle appears', (
      tester,
    ) async {
      final repo = FakeVehicleRepository();
      await openVehicles(tester, repo);

      await tester.tap(find.text('Register vehicle').first);
      await tester.pumpAndSettle();
      await fillForm(tester);
      await submit(tester, 'Register vehicle');

      expect(repo.created, hasLength(1));
      expect(
        repo.created.single.vehicleNumber,
        'new 777',
        reason: 'the form sends what was typed; the server owns normalization',
      );
      expect(repo.created.single.status, VehicleStatus.active);
      expect(
        find.text('NEW 777 registered'),
        findsOneWidget,
        reason: 'the UI shows the server-normalized number',
      );
      expect(find.text('NEW 777'), findsOneWidget);
    });

    testWidgets('a duplicate number from the server is shown on that field', (
      tester,
    ) async {
      const message = 'A vehicle with vehicle number NEW 777 already exists';
      final repo = FakeVehicleRepository()
        ..createError = const ApiException(
          kind: ApiErrorKind.conflict,
          message: message,
          statusCode: 409,
          fieldErrors: {'vehicleNumber': message},
        );
      await openVehicles(tester, repo);

      await tester.tap(find.text('Register vehicle').first);
      await tester.pumpAndSettle();
      await fillForm(tester);
      await submit(tester, 'Register vehicle');

      expect(find.text(message), findsOneWidget);
      expect(find.text('Register vehicle'), findsWidgets); // still on the form
      expect(repo.vehicles, isEmpty);

      // Editing the field clears the server's message.
      await tester.enterText(field('Vehicle number *'), 'NEW 778');
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
    });

    testWidgets('other server errors appear in a banner and keep the input', (
      tester,
    ) async {
      final repo = FakeVehicleRepository()..createError = networkDown;
      await openVehicles(tester, repo);

      await tester.tap(find.text('Register vehicle').first);
      await tester.pumpAndSettle();
      await fillForm(tester);
      await submit(tester, 'Register vehicle');

      expect(find.textContaining('Could not save the vehicle'), findsOneWidget);
      expect(find.textContaining(networkDown.message), findsOneWidget);
      expect(find.text('Scania'), findsOneWidget); // typed input preserved
      expect(repo.vehicles, isEmpty);
    });

    testWidgets('empty required fields are caught before any request', (
      tester,
    ) async {
      final repo = FakeVehicleRepository();
      await openVehicles(tester, repo);

      await tester.tap(find.text('Register vehicle').first);
      await tester.pumpAndSettle();
      await submit(tester, 'Register vehicle');

      expect(find.textContaining('Enter the vehicle number'), findsOneWidget);
      expect(repo.created, isEmpty);
    });
  });

  group('update', () {
    testWidgets('edits an existing vehicle through the server', (tester) async {
      final repo = FakeVehicleRepository([sampleVehicle(id: 5)]);
      await openVehicles(tester, repo);

      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();
      expect(find.text('Edit vehicle'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(field('Brand *')).controller!.text,
        'Volvo',
      );

      await tester.enterText(field('Brand *'), 'Scania');
      await submit(tester, 'Save changes');

      expect(repo.vehicles.single.id, 5);
      expect(repo.vehicles.single.brand, 'Scania');
      expect(find.text('AB 12345 updated'), findsOneWidget);
    });

    testWidgets('a failed update stays on the form with the reason', (
      tester,
    ) async {
      final repo = FakeVehicleRepository([sampleVehicle(id: 5)])
        ..updateError = const ApiException(
          kind: ApiErrorKind.notFound,
          message:
              'This vehicle no longer exists. It may have been deleted. '
              'Go back and refresh the list.',
          statusCode: 404,
        );
      await openVehicles(tester, repo);

      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();
      await submit(tester, 'Save changes');

      expect(find.textContaining('no longer exists'), findsOneWidget);
      expect(find.text('Edit vehicle'), findsOneWidget);
    });
  });
}
