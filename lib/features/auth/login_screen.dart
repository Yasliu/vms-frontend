import 'package:material_ui/material_ui.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/fade_slide_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Mock sign-in: any valid-looking email and non-empty password is accepted.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.shell);
  }

  @override
  Widget build(BuildContext context) {
    final showBrandPanel = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: Row(
        children: [
          if (showBrandPanel) const Expanded(flex: 5, child: _BrandPanel()),
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
              FadeSlideIn(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Text(
                      'STARK GROUP',
                      style: theme.textTheme.titleMedium?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
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
                controller: _passwordController,
                obscureText: _obscure,
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
              child: Text(
                'Demo mode: any valid email and password will work.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final padding = MediaQuery.sizeOf(context).width < 1200
        ? AppSpacing.xxl - 8
        : AppSpacing.xxl + 16;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navyLight],
        ),
      ),
      padding: EdgeInsets.all(padding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.elasticOut,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: const Icon(
              Icons.local_shipping_rounded,
              size: 64,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            offset: const Offset(-0.1, 0),
            child: Text(
              'STARK GROUP',
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.accent,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FadeSlideIn(
            delay: const Duration(milliseconds: 280),
            offset: const Offset(-0.1, 0),
            child: Text(
              'Vehicle Management System',
              style: textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FadeSlideIn(
            delay: const Duration(milliseconds: 380),
            offset: const Offset(-0.1, 0),
            child: Text(
              'Register, track and maintain every vehicle in your fleet '
              'from one simple dashboard.',
              style: textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
