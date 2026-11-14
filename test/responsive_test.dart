import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vms_frontend/app.dart';

void main() {
  for (final size in const [Size(390, 844), Size(820, 1000), Size(1440, 900)]) {
    testWidgets('login, list and form lay out at ${size.width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const VmsApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText).at(0), 'a@b.com');
      await tester.enterText(find.byType(EditableText).at(1), 'pw');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('AB 12345'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).first, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No vehicles match your search'), findsOneWidget);

      await tester.tap(find.text('Clear filters').first);
      await tester.pumpAndSettle();
      expect(find.text('AB 12345'), findsOneWidget);

      await tester.tap(
        find.text(size.width < 600 ? 'Add' : 'Register vehicle').first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Register vehicle').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Register vehicle').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter the vehicle number'), findsOneWidget);
    });
  }
}
