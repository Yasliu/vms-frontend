import 'package:material_ui/material_ui.dart';

import '../theme/app_tokens.dart';

enum AppButtonVariant { filled, outlined, danger }

/// A button with hover/press scaling and a built-in loading state.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = AppButtonVariant.filled,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final AppButtonVariant variant;
  final bool expand;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  double get _scale {
    if (!_enabled) return 1;
    if (_pressed) return 0.96;
    if (_hovered) return 1.03;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final variant = widget.variant;
    final spinnerColor = switch (variant) {
      AppButtonVariant.filled => scheme.onPrimary,
      AppButtonVariant.danger => scheme.onError,
      AppButtonVariant.outlined => scheme.primary,
    };

    final content = AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: widget.isLoading
            ? SizedBox(
                key: const ValueKey('loading'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: spinnerColor,
                ),
              )
            : Row(
                key: const ValueKey('label'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(widget.label),
                ],
              ),
      ),
    );

    // While loading we keep the button looking active but ignore taps.
    final VoidCallback? onPressed = !_enabled
        ? null
        : (widget.isLoading ? () {} : widget.onPressed);

    final button = switch (variant) {
      AppButtonVariant.filled => FilledButton(
        onPressed: onPressed,
        child: content,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
        ),
        child: content,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        onPressed: onPressed,
        child: content,
      ),
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: widget.expand
              ? SizedBox(width: double.infinity, child: button)
              : button,
        ),
      ),
    );
  }
}
