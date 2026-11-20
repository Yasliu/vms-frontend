import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vms_frontend/app.dart';
import 'package:vms_frontend/core/config/app_config.dart';

import 'fake_auth_repository.dart';
import 'fake_backend.dart';
import 'fake_vehicle_repository.dart';

/// Opens the app on a desktop-sized window, without signing in.
Future<void> openApp(
  WidgetTester tester,
  FakeVehicleRepository repository, {
  FakeAuthRepository? auth,
  Size size = const Size(1440, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    VmsApp(
      repository: repository,
      authRepository: auth ?? FakeAuthRepository(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> typeCredentials(
  WidgetTester tester, {
  String email = validEmail,
  String password = validPassword,
}) async {
  await tester.enterText(find.byType(EditableText).at(0), email);
  await tester.enterText(find.byType(EditableText).at(1), password);
}

/// Opens the app and signs in with valid credentials. With `settle: false` it
/// returns as soon as the vehicle screen starts, so loading states can be
/// observed.
Future<void> openVehicles(
  WidgetTester tester,
  FakeVehicleRepository repository, {
  FakeAuthRepository? auth,
  Size size = const Size(1440, 900),
  bool settle = true,
}) async {
  await openApp(tester, repository, auth: auth, size: size);

  await typeCredentials(tester);
  await tester.tap(find.text('Sign in'));
  if (settle) {
    await tester.pumpAndSettle(const Duration(seconds: 2));
  } else {
    // Past the sign-in call and the route transition, but not settled.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

/// The real app (UI, controllers, repositories, ApiClient) talking to a fake
/// server over a fake HTTP transport.
Future<FakeBackend> openAgainstBackend(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final backend = FakeBackend();
  await tester.pumpWidget(
    VmsApp(
      config: const AppConfig(apiBaseUrl: 'http://api.test'),
      httpClient: backend.client,
    ),
  );
  await tester.pumpAndSettle();
  return backend;
}

/// Fills the sign-up form (email, password, confirm, registration code).
Future<void> typeSignUp(
  WidgetTester tester, {
  String email = 'new.user@example.com',
  String password = 'a-brand-new-password-1',
  String? confirm,
  String code = validRegistrationCode,
}) async {
  await tester.enterText(find.byType(EditableText).at(0), email);
  await tester.enterText(find.byType(EditableText).at(1), password);
  await tester.enterText(find.byType(EditableText).at(2), confirm ?? password);
  await tester.enterText(find.byType(EditableText).at(3), code);
}
