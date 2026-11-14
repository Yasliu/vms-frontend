import 'package:material_ui/material_ui.dart';

import '../../features/auth/login_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/vehicles/vehicle_form_screen.dart';
import '../../features/vehicles/vehicle_list_screen.dart';
import '../../models/vehicle.dart';
import 'app_routes.dart';
import 'page_transitions.dart';

class AppRouter {
  AppRouter._();

  /// Top-level routes: login and the application shell.
  static Route<dynamic> onGenerateRootRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.shell:
        return fadeScaleRoute(const AppShell(), settings);
      case AppRoutes.login:
      default:
        return fadeScaleRoute(const LoginScreen(), settings);
    }
  }

  /// Routes shown inside the shell's content area.
  static Route<dynamic> onGenerateInnerRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.vehicleNew:
        return slideRoute(const VehicleFormScreen(), settings);
      case AppRoutes.vehicleEdit:
        final vehicle = settings.arguments as Vehicle?;
        return slideRoute(VehicleFormScreen(vehicle: vehicle), settings);
      case AppRoutes.vehicles:
      default:
        return slideRoute(const VehicleListScreen(), settings);
    }
  }
}
