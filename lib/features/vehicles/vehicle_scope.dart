import 'package:material_ui/material_ui.dart';

import 'vehicle_controller.dart';

/// Makes the [VehicleController] available to the vehicle screens.
class VehicleScope extends InheritedWidget {
  const VehicleScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final VehicleController controller;

  static VehicleController of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<VehicleScope>();
    assert(scope != null, 'No VehicleScope found above this widget.');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(VehicleScope oldWidget) =>
      controller != oldWidget.controller;
}
