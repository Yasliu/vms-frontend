import 'package:flutter_test/flutter_test.dart';
import 'package:vms_frontend/app.dart';

void main() {
  testWidgets('shows the login screen first', (tester) async {
    await tester.pumpWidget(const VmsApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
