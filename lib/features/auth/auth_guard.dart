import 'package:material_ui/material_ui.dart';

import '../../core/routing/app_routes.dart';
import 'session_scope.dart';

/// Shows [child] only while someone is signed in. When the session ends
/// (sign-out, expiry) or was never started (for example a page reload on
/// `/app`), it sends the user to the sign-in screen.
class AuthGuard extends StatefulWidget {
  const AuthGuard({super.key, required this.child});

  final Widget child;

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _redirecting = false;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.isSignedIn) return widget.child;

        if (!_redirecting) {
          _redirecting = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context)
                .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
          });
        }
        return const SizedBox.shrink();
      },
    );
  }
}
