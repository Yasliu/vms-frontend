import 'package:material_ui/material_ui.dart';

import 'session_controller.dart';

/// Makes the [SessionController] available to the screens.
class SessionScope extends InheritedWidget {
  const SessionScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final SessionController controller;

  static SessionController of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No SessionScope found above this widget.');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(SessionScope oldWidget) =>
      controller != oldWidget.controller;
}
