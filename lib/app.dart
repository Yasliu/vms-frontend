import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/routing/app_router.dart';
import 'core/routing/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'data/api_auth_repository.dart';
import 'data/api_vehicle_repository.dart';
import 'data/auth_repository.dart';
import 'data/vehicle_repository.dart';
import 'features/auth/session_controller.dart';
import 'features/auth/session_scope.dart';
import 'features/vehicles/vehicle_controller.dart';
import 'features/vehicles/vehicle_scope.dart';

class VmsApp extends StatefulWidget {
  /// Pass repositories to run the app against something other than the real
  /// backend (tests, demos).
  const VmsApp({
    super.key,
    this.repository,
    this.authRepository,
    this.config,
    this.httpClient,
  });

  final VehicleRepository? repository;
  final AuthRepository? authRepository;
  final AppConfig? config;

  /// Replaces the network transport (tests); the real app leaves this null.
  final http.Client? httpClient;

  @override
  State<VmsApp> createState() => _VmsAppState();
}

class _VmsAppState extends State<VmsApp> {
  ApiClient? _apiClient;
  late final SessionController _session;
  late final VehicleController _vehicles;

  @override
  void initState() {
    super.initState();
    var vehicleRepository = widget.repository;
    var authRepository = widget.authRepository;

    if (vehicleRepository == null || authRepository == null) {
      final config = widget.config ?? AppConfig.fromEnvironment();
      // The client reads the token from the session and reports rejected
      // tokens back to it; the closures are only called after _session exists.
      final client = ApiClient(
        baseUrl: config.apiBaseUrl,
        timeout: config.requestTimeout,
        httpClient: widget.httpClient,
        tokenProvider: () => _session.accessToken,
        onUnauthorized: () => _session.expire(),
      );
      _apiClient = client;
      vehicleRepository ??= ApiVehicleRepository(client);
      authRepository ??= ApiAuthRepository(client);
    }

    _session = SessionController(authRepository);
    _vehicles = VehicleController(vehicleRepository);
    _session.addListener(_onSessionChanged);
  }

  // Never keep one user's vehicle data around after they sign out.
  void _onSessionChanged() {
    if (!_session.isSignedIn) _vehicles.reset();
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    _vehicles.dispose();
    _apiClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      controller: _session,
      child: VehicleScope(
        controller: _vehicles,
        child: MaterialApp(
          title: 'VMS Admin',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          initialRoute: AppRoutes.login,
          onGenerateRoute: AppRouter.onGenerateRootRoute,
        ),
      ),
    );
  }
}
