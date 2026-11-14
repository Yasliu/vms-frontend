import 'package:material_ui/material_ui.dart';

import '../theme/app_tokens.dart';

/// A titled group of form fields. On wide screens the title sits to the left
/// of the fields; on narrow screens it stacks above them.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Padding(
          padding: EdgeInsets.all(wide ? AppSpacing.lg : AppSpacing.md),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 240, child: header),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(child: child),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: AppSpacing.md),
                    child,
                  ],
                ),
        );
      },
    );
  }
}

/// Marks a field that should span the whole row inside a [FieldGrid].
class FullWidth extends StatelessWidget {
  const FullWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Lays fields out in 1 or 2 columns depending on the available width.
class FieldGrid extends StatelessWidget {
  const FieldGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 480 ? 2 : 1;
        final itemWidth =
            (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final c in children)
              SizedBox(
                width: c is FullWidth ? constraints.maxWidth : itemWidth,
                child: c,
              ),
          ],
        );
      },
    );
  }
}
