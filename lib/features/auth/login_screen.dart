import 'package:material_ui/material_ui.dart';

import '../../core/network/api_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/fade_slide_in.dart';
import 'session_scope.dart';
import 'widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Changing this gives the password field a fresh state (no validation
  // history), so a cleared field does not show a "required" error.
  int _passwordGeneration = 0;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    final session = SessionScope.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await session.login(_emailController.text, _passwordController.text);
    } on ApiException catch (e) {
      _fail(e.message);
      return;
    } on Exception {
      _fail('Something went wrong while signing in. Please try again.');
      return;
    }

    if (!mounted) return;
    // The password is not needed any more; do not leave it in the field.
    _passwordController.clear();
    navigator.pushReplacementNamed(AppRoutes.shell);
  }

  void _fail(String message) {
    if (!mounted) return;
    // Clear the password after every failed attempt; keep the email.
    _passwordController.clear();
    setState(() {
      _passwordGeneration++;
      _loading = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showBrandPanel = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: Row(
        children: [
          if (showBrandPanel) const Expanded(flex: 5, child: AuthBrandPanel()),
          Expanded(
            flex: 4,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  showBrandPanel ? AppSpacing.xl : AppSpacing.lg - 4,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildForm(context, showBrandPanel),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, bool showBrandPanel) {
    final theme = Theme.of(context);
    const step = Duration(milliseconds: 90);

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!showBrandPanel) ...[
              const FadeSlideIn(child: AuthBrandMark()),
              const SizedBox(height: AppSpacing.xl),
            ],
            FadeSlideIn(
              child: Semantics(
                header: true,
                child: Text(
                  'Welcome back',
                  style: theme.textTheme.headlineMedium,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FadeSlideIn(
              delay: step,
              child: Text(
                'Sign in to manage your fleet.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AuthMessageBanner(
              message: _error ?? SessionScope.of(context).notice,
              isError: _error != null,
            ),
            FadeSlideIn(
              delay: step * 2,
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  hintText: 'name@company.com',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Enter your email address.';
                  if (!text.contains('@') || !text.contains('.')) {
                    return 'Enter a valid email, for example name@company.com.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: step * 3,
              child: TextFormField(
                key: ValueKey('password-$_passwordGeneration'),
                controller: _passwordController,
                obscureText: _obscure,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        key: ValueKey(_obscure),
                      ),
                    ),
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter your password.'
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: step * 4,
              child: AppButton(
                label: 'Sign in',
                icon: Icons.login,
                expand: true,
                isLoading: _loading,
                onPressed: _submit,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: step * 5,
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () =>
                              Navigator.of(context)
                                  .pushReplacementNamed(AppRoutes.register),
                    child: const Text('Sign up'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
