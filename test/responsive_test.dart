import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_vehicle_repository.dart';
import 'support/test_app.dart';

void main() {
  for (final size in const [Size(390, 844), Size(820, 1000), Size(1440, 900)]) {
    testWidgets('list and form lay out at ${size.width.toInt()}px', (
      tester,
    ) async {
      await openVehicles(
        tester,
        FakeVehicleRepository([
          sampleVehicle(),
          sampleVehicle(
            id: 2,
            number: 'CD 67890',
            brand: 'Ford',
            model: 'Transit',
            type: 'Van',
          ),
        ]),
        size: size,
      );

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
