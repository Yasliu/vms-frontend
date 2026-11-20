import 'package:material_ui/material_ui.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/network/api_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/fade_slide_in.dart';
import 'session_scope.dart';
import 'widgets/auth_widgets.dart';

/// Self-service sign-up. The server only accepts it with the shared
/// registration code, and the new account is signed in straight away.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // Same limits as the backend (password is also capped at 72 bytes there).
  static const _minPassword = 12;
  static const _maxPassword = 72;
  static const _maxCode = 200;
  static const _fieldsShown = {'email', 'password', 'registrationCode'};

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureCode = true;
  bool _loading = false;
  String? _error;

  // Problems reported by the server, shown until the field is edited.
  Map<String, String> _serverErrors = {};

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _code.dispose();
    super.dispose();
  }

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field) || _error != null) {
      setState(() {
        _serverErrors = {..._serverErrors}..remove(field);
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _serverErrors = {};
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final session = SessionScope.of(context);
    final navigator = Navigator.of(context);
    setState(() => _loading = true);

    try {
      await session.register(_email.text, _password.text, _code.text);
    } on ApiException catch (e) {
      _fail(e);
      return;
    } on Exception {
      _fail(
        const ApiException(
          kind: ApiErrorKind.unexpected,
          message:
              'Something went wrong while creating the account. '
              'Please try again.',
        ),
      );
      return;
    }

    if (!mounted) return;
    // Nothing secret needs to stay in the form once the account exists.
    _password.clear();
    _confirm.clear();
    _code.clear();
    navigator.pushReplacementNamed(AppRoutes.shell);
  }

  void _fail(ApiException e) {
    if (!mounted) return;
    // Field errors show under their fields; anything else goes in the banner.
    final elsewhere = e.fieldErrors.entries
        .where((entry) => !_fieldsShown.contains(entry.key))
        .map((entry) => entry.value);
    final onFields = e.fieldErrors.keys.any(_fieldsShown.contains);
    setState(() {
      _loading = false;
      _serverErrors = e.fieldErrors;
      _error = e.fieldErrors.isEmpty
          ? e.message
          : (elsewhere.isEmpty ? null : elsewhere.join(' '));
    });
    if (onFields) _formKey.currentState!.validate();
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
    const step = Duration(milliseconds: 80);
    final narrow = MediaQuery.sizeOf(context).width < Breakpoints.compact;

    Widget toggle(bool obscured, VoidCallback onTap, String what) {
      return IconButton(
        tooltip: obscured ? 'Show $what' : 'Hide $what',
        onPressed: onTap,
        icon: Icon(
          obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      );
    }

    // Each field validates once the user has touched *that* field. A form-level
    // onUserInteraction would flag every empty field as soon as the first one
    // is edited.
    return Form(
      key: _formKey,
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
                  'Create your account',
                  style: theme.textTheme.headlineMedium,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FadeSlideIn(
              delay: step,
              child: Text(
                'Sign up to manage your fleet.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(height: narrow ? AppSpacing.lg : AppSpacing.xl),
            AuthMessageBanner(message: _error, isError: true),
            FadeSlideIn(
              delay: step * 2,
              child: TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                onChanged: (_) => _clearServerError('email'),
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
                  return _serverErrors['email'];
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: step * 3,
              child: TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _password,
                obscureText: _obscurePassword,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => _clearServerError('password'),
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'At least $_minPassword characters',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: toggle(
                    _obscurePassword,
                    () => setState(() => _obscurePassword = !_obscurePassword),
                    'password',
                  ),
                ),
                validator: (value) {
                  final text = value ?? '';
                  if (text.isEmpty) return 'Enter a password.';
                  if (text.length < _minPassword ||
                      text.length > _maxPassword) {
                    return 'Use $_minPassword to $_maxPassword characters '
                        'for the password.';
                  }
                  return _serverErrors['password'];
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: step * 4,
              child: TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _confirm,
                obscureText: _obscurePassword,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (value) {
                  if ((value ?? '').isEmpty) return 'Enter the password again.';
                  if (value != _password.text) {
                    return 'The two passwords do not match.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: step * 5,
              child: TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _code,
                obscureText: _obscureCode,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onChanged: (_) => _clearServerError('registrationCode'),
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Registration code',
                  helperText: 'Ask your administrator for the code',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  suffixIcon: toggle(
                    _obscureCode,
                    () => setState(() => _obscureCode = !_obscureCode),
                    'code',
                  ),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'Enter the registration code.';
                  if (text.length > _maxCode) return 'That code is too long.';
                  return _serverErrors['registrationCode'];
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: step * 6,
              child: AppButton(
                label: 'Create account',
                icon: Icons.person_add_alt_1_outlined,
                expand: true,
                isLoading: _loading,
                onPressed: _submit,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: step * 7,
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () =>
                              Navigator.of(context)
                                  .pushReplacementNamed(AppRoutes.login),
                    child: const Text('Sign in'),
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
