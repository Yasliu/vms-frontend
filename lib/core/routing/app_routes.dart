class AppRoutes {
  AppRoutes._();

  // Root navigator
  static const login = '/login';
  static const register = '/register';
  static const shell = '/app';

  // Inner navigator (inside the application shell)
  static const vehicles = '/vehicles';
  static const vehicleNew = '/vehicles/new';
  static const vehicleEdit = '/vehicles/edit';
}
