import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/fade_slide_in.dart';

/// Sidebar + content area. Screens inside the content area are shown by a
/// nested [Navigator], so only the content slides when you navigate.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _currentRoute = ValueNotifier<String>(AppRoutes.vehicles);
  late final _RouteObserver _observer = _RouteObserver(_currentRoute);

  @override
  void dispose() {
    _currentRoute.dispose();
    super.dispose();
  }

  NavigatorState get _navigator => _navigatorKey.currentState!;

  void _goToVehicles() {
    _navigator.popUntil((route) => route.isFirst);
  }

  void _goToNewVehicle() {
    if (_currentRoute.value == AppRoutes.vehicleNew) return;
    _navigator.pushNamedAndRemoveUntil(
      AppRoutes.vehicleNew,
      (route) => route.isFirst,
    );
  }

  void _logout() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  Widget _sidebar({bool collapsed = false, VoidCallback? beforeNavigate}) {
    return ValueListenableBuilder<String>(
      valueListenable: _currentRoute,
      builder: (context, route, _) => _Sidebar(
        currentRoute: route,
        collapsed: collapsed,
        onVehicles: () {
          beforeNavigate?.call();
          _goToVehicles();
        },
        onNewVehicle: () {
          beforeNavigate?.call();
          _goToNewVehicle();
        },
        onLogout: () {
          beforeNavigate?.call();
          _logout();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < Breakpoints.compact;
    final isRail = width < Breakpoints.expanded;
    final sidebarWidth = isRail ? 76.0 : 260.0;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: isCompact ? AppBar(title: const _BrandMark()) : null,
      drawer: isCompact
          ? Drawer(
              child: Builder(
                builder: (drawerContext) => _sidebar(
                  beforeNavigate: () => Navigator.of(drawerContext).pop(),
                ),
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isCompact)
            FadeSlideIn(
              offset: const Offset(-0.2, 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                width: sidebarWidth,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(
                    right: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                // Lay the sidebar out at its final width and let the
                // container reveal it, so resizing never overflows.
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: sidebarWidth,
                    maxWidth: sidebarWidth,
                    child: _sidebar(collapsed: isRail),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Navigator(
                  key: _navigatorKey,
                  initialRoute: AppRoutes.vehicles,
                  observers: [_observer],
                  onGenerateRoute: AppRouter.onGenerateInnerRoute,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps [notifier] in sync with the route currently visible in the shell.
class _RouteObserver extends NavigatorObserver {
  _RouteObserver(this.notifier);

  final ValueNotifier<String> notifier;

  void _update(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (notifier.value != name) notifier.value = name;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _update(newRoute);
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.currentRoute,
    required this.collapsed,
    required this.onVehicles,
    required this.onNewVehicle,
    required this.onLogout,
  });

  final String currentRoute;
  final bool collapsed;
  final VoidCallback onVehicles;
  final VoidCallback onNewVehicle;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final align = collapsed
        ? MainAxisAlignment.center
        : MainAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm + 4,
        AppSpacing.lg,
        AppSpacing.sm + 4,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : AppSpacing.sm + 4,
            ),
            child: _BrandMark(collapsed: collapsed),
          ),
          const SizedBox(height: AppSpacing.xl),
          _NavItem(
            icon: Icons.directions_car_outlined,
            label: 'Vehicles',
            collapsed: collapsed,
            selected:
                currentRoute == AppRoutes.vehicles ||
                currentRoute == AppRoutes.vehicleEdit,
            onTap: onVehicles,
          ),
          _NavItem(
            icon: Icons.add_circle_outline,
            label: 'Register vehicle',
            collapsed: collapsed,
            selected: currentRoute == AppRoutes.vehicleNew,
            onTap: onNewVehicle,
          ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : AppSpacing.sm + 4,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: align,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.primary,
                  child: const Text('A'),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin', style: theme.textTheme.titleSmall),
                        Text(
                          'admin@vms.com',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          _NavItem(
            icon: Icons.logout,
            label: 'Sign out',
            collapsed: collapsed,
            selected: false,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final collapsed = widget.collapsed;
    final foreground = widget.selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    final background = widget.selected
        ? scheme.primaryContainer
        : _hovered
        ? AppColors.tableHeader
        : Colors.transparent;

    final item = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
          padding: collapsed
              ? const EdgeInsets.symmetric(vertical: 12)
              : EdgeInsets.fromLTRB(_hovered ? 18 : 14, 12, 14, 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(widget.icon, size: 20, color: foreground),
              if (!collapsed) ...[
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return collapsed ? Tooltip(message: widget.label, child: item) : item;
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.collapsed = false});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Icon(
        Icons.local_shipping_rounded,
        size: 18,
        color: AppColors.accent,
      ),
    );
    if (collapsed) return Center(child: mark);

    return Semantics(
      label: 'Stark Group Vehicle Management System',
      excludeSemantics: true,
      child: Row(
        children: [
          mark,
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STARK GROUP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  'Vehicle Management',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
