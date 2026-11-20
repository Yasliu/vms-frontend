import 'package:flutter_test/flutter_test.dart';
import 'package:vms_frontend/app.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_vehicle_repository.dart';

void main() {
  testWidgets('shows the login screen first', (tester) async {
    await tester.pumpWidget(
      VmsApp(
        repository: FakeVehicleRepository(),
        authRepository: FakeAuthRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
