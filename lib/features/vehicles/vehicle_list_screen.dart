import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/animated_collapse.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/page_header.dart';
import '../../core/network/api_exception.dart';
import '../../models/vehicle.dart';
import 'vehicle_controller.dart';
import 'vehicle_scope.dart';
import 'widgets/vehicle_visuals.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  late final VehicleController _controller;
  final _searchController = TextEditingController();
  String _query = '';
  VehicleStatus? _statusFilter;

  // Rows that were deleted and are currently animating out.
  // Rows with a delete request in flight: still shown, but busy.
  final _deleting = <int>{};
  // Rows the server has deleted and that are animating out.
  final _removing = <int>{};
  // False during the first build so existing rows use the staggered intro;
  // rows added later grow into place instead.
  bool _initialized = false;

  bool get _hasFilters => _query.trim().isNotEmpty || _statusFilter != null;

  @override
  void initState() {
    super.initState();
    _controller = VehicleScope.of(context)..ensureLoaded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initialized = true;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isVisible(Vehicle v) {
    if (_removing.contains(v.id)) return false;
    final q = _query.trim().toLowerCase();
    final matchesStatus = _statusFilter == null || v.status == _statusFilter;
    final matchesQuery =
        q.isEmpty ||
        v.vehicleNumber.toLowerCase().contains(q) ||
        v.company.toLowerCase().contains(q) ||
        v.displayName.toLowerCase().contains(q) ||
        v.type.toLowerCase().contains(q);
    return matchesStatus && matchesQuery;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _statusFilter = null;
    });
  }

  Future<void> _confirmDelete(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.delete_outline,
          size: 32,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Delete this vehicle?'),
        content: Text(
          '${vehicle.vehicleNumber} · ${vehicle.displayName} will be '
          'removed from the vehicle list.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.outlined,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton(
            label: 'Delete',
            variant: AppButtonVariant.danger,
            icon: Icons.delete_outline,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (_deleting.contains(vehicle.id)) return;
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    // The row stays visible (and busy) until the server confirms.
    setState(() => _deleting.add(vehicle.id));
    try {
      await _controller.delete(
        vehicle,
        beforeRemoval: () async {
          if (!mounted) return;
          setState(() => _removing.add(vehicle.id));
          // Let the row collapse before it leaves the data.
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
      );
      messenger.showSnackBar(
        SnackBar(content: Text('${vehicle.vehicleNumber} deleted')),
      );
    } on ApiException catch (e) {
      // After a timeout the server may have deleted it; the controller has
      // already re-read the list, so say so instead of just "try again".
      final message = e.kind == ApiErrorKind.timeout
          ? 'No answer from the server while deleting ${vehicle.vehicleNumber}. '
                'The list was refreshed with the latest data.'
          : 'Could not delete ${vehicle.vehicleNumber}. ${e.message}';
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: errorColor,
          // Errors need more reading time than the default 4 seconds.
          duration: const Duration(seconds: 7),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deleting.remove(vehicle.id);
          _removing.remove(vehicle.id);
        });
      }
    }
  }

  void _edit(Vehicle vehicle) {
    Navigator.of(context).pushNamed(AppRoutes.vehicleEdit, arguments: vehicle);
  }

  void _register() => Navigator.of(context).pushNamed(AppRoutes.vehicleNew);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final all = _controller.vehicles;
        final current = all.where((v) => !_removing.contains(v.id)).toList();
        final visibleCount = all.where(_isVisible).length;
        final phase = _controller.phase;

        return ListView(
          padding: EdgeInsets.all(Breakpoints.pagePadding(width)),
          children: [
            FadeSlideIn(
              child: PageHeader(
                title: 'Vehicles',
                subtitle: 'Manage and monitor your fleet',
                action: AppButton(
                  label: width < 600 ? 'Add' : 'Register vehicle',
                  icon: Icons.add,
                  onPressed: _register,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (phase == VehicleListPhase.loading)
              const _LoadingState()
            else if (phase == VehicleListPhase.failed)
              _ErrorState(
                message: _controller.error ?? 'Something went wrong.',
                onRetry: _controller.load,
              )
            else ...[
              if (_controller.error != null) ...[
                _RefreshErrorBanner(
                  message: _controller.error!,
                  onRetry: _controller.load,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _StatsRow(vehicles: current),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: _Filters(
                  controller: _searchController,
                  selected: _statusFilter,
                  onQueryChanged: (value) => setState(() => _query = value),
                  onStatusChanged: (value) =>
                      setState(() => _statusFilter = value),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ResultsBar(
                shown: visibleCount,
                total: current.length,
                showClear: _hasFilters,
                onClear: _clearFilters,
                isRefreshing: _controller.isRefreshing,
                onRefresh: _controller.load,
              ),
              const SizedBox(height: AppSpacing.sm),
              _VehicleTable(
                vehicles: all,
                isVisible: _isVisible,
                deleting: _deleting,
                animateIn: _initialized,
                hasVehicles: current.isNotEmpty,
                onEdit: _edit,
                onDelete: _confirmDelete,
                onClearFilters: _clearFilters,
                onRegister: _register,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xxl,
          horizontal: AppSpacing.lg,
        ),
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: 'Loading vehicles',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Loading vehicles…', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xxl,
          horizontal: AppSpacing.lg,
        ),
        child: Center(
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_off_outlined,
                    size: 40,
                    color: scheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Could not load vehicles',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Try again',
                  icon: Icons.refresh,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RefreshErrorBanner extends StatelessWidget {
  const _RefreshErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                'Could not refresh the list. $message Showing the last '
                'loaded data.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.vehicles});

  final List<Vehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    int count(VehicleStatus s) => vehicles.where((v) => v.status == s).length;

    final stats = [
      (
        'Total vehicles',
        vehicles.length,
        Icons.directions_car_outlined,
        AppColors.navy,
      ),
      (
        'Active',
        count(VehicleStatus.active),
        Icons.check_circle_outline,
        vehicleStatusColor(VehicleStatus.active),
      ),
      (
        'Inactive',
        count(VehicleStatus.inactive),
        Icons.pause_circle_outline,
        vehicleStatusColor(VehicleStatus.inactive),
      ),
      (
        'Under maintenance',
        count(VehicleStatus.underMaintenance),
        Icons.build_outlined,
        vehicleStatusColor(VehicleStatus.underMaintenance),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.md;
        final columns = constraints.maxWidth >= 800 ? 4 : 2;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < stats.length; i++)
              FadeSlideIn(
                delay: Duration(milliseconds: 80 * (i + 1)),
                child: SizedBox(
                  width: width,
                  child: _StatCard(
                    label: stats[i].$1,
                    value: stats[i].$2,
                    icon: stats[i].$3,
                    color: stats[i].$4,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatefulWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 600;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        offset: _hovered ? const Offset(0, -0.04) : Offset.zero,
        child: Semantics(
          label: '${widget.label}: ${widget.value}',
          excludeSemantics: true,
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(narrow ? AppSpacing.md : 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(widget.icon, color: widget.color),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: widget.value),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => Text(
                            '$value',
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                        Text(
                          widget.label,
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
            ),
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.controller,
    required this.selected,
    required this.onQueryChanged,
    required this.onStatusChanged,
  });

  final TextEditingController controller;
  final VehicleStatus? selected;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<VehicleStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md - 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: math.min(340, constraints.maxWidth),
            child: TextField(
              controller: controller,
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                labelText: 'Search vehicles',
                hintText: 'Number, company, brand, model or type',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: selected == null,
                onSelected: (_) => onStatusChanged(null),
              ),
              for (final status in VehicleStatus.values)
                ChoiceChip(
                  label: Text(status.label),
                  selected: selected == status,
                  onSelected: (_) => onStatusChanged(status),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultsBar extends StatelessWidget {
  const _ResultsBar({
    required this.shown,
    required this.total,
    required this.showClear,
    required this.onClear,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final int shown;
  final int total;
  final bool showClear;
  final VoidCallback onClear;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Align(
                key: ValueKey('$shown/$total'),
                alignment: Alignment.centerLeft,
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    'Showing $shown of $total vehicles',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: showClear
                ? TextButton.icon(
                    key: const ValueKey('clear'),
                    onPressed: onClear,
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                    label: const Text('Clear filters'),
                  )
                : const SizedBox.shrink(key: ValueKey('none')),
          ),
          isRefreshing
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.sm + 4),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Refresh list',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasVehicles,
    required this.onClearFilters,
    required this.onRegister,
  });

  final bool hasVehicles;
  final VoidCallback onClearFilters;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Padding(
        key: ValueKey(hasVehicles),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xxl,
          horizontal: AppSpacing.lg,
        ),
        child: Center(
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.navyTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasVehicles
                        ? Icons.search_off
                        : Icons.directions_car_outlined,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  hasVehicles
                      ? 'No vehicles match your search'
                      : 'No vehicles registered yet',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Text(
                    hasVehicles
                        ? 'Try a different search term or clear the filters '
                              'to see every vehicle.'
                        : 'Register your first vehicle to start managing '
                              'your fleet.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                hasVehicles
                    ? AppButton(
                        label: 'Clear filters',
                        icon: Icons.filter_alt_off_outlined,
                        variant: AppButtonVariant.outlined,
                        onPressed: onClearFilters,
                      )
                    : AppButton(
                        label: 'Register vehicle',
                        icon: Icons.add,
                        onPressed: onRegister,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _TableLayout { full, medium, compact }

_TableLayout _layoutFor(double width) {
  if (width >= 980) return _TableLayout.full;
  if (width >= 620) return _TableLayout.medium;
  return _TableLayout.compact;
}

double _actionsWidth(_TableLayout layout) =>
    layout == _TableLayout.full ? 200 : 96;

class _VehicleTable extends StatelessWidget {
  const _VehicleTable({
    required this.vehicles,
    required this.isVisible,
    required this.deleting,
    required this.animateIn,
    required this.hasVehicles,
    required this.onEdit,
    required this.onDelete,
    required this.onClearFilters,
    required this.onRegister,
  });

  final List<Vehicle> vehicles;
  final bool Function(Vehicle) isVisible;
  final Set<int> deleting;
  final bool animateIn;
  final bool hasVehicles;
  final ValueChanged<Vehicle> onEdit;
  final ValueChanged<Vehicle> onDelete;
  final VoidCallback onClearFilters;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _layoutFor(constraints.maxWidth);
          var visibleCount = 0;
          final rows = <Widget>[];

          for (var i = 0; i < vehicles.length; i++) {
            final vehicle = vehicles[i];
            final visible = isVisible(vehicle);
            final showDivider = visible && visibleCount > 0;
            if (visible) visibleCount++;

            rows.add(
              AnimatedCollapse(
                key: ValueKey(vehicle.id),
                visible: visible,
                animateIn: animateIn,
                child: Column(
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: showDivider ? 1 : 0,
                      child: const Divider(),
                    ),
                    FadeSlideIn(
                      delay: animateIn
                          ? Duration.zero
                          : Duration(milliseconds: 40 * math.min(i, 8)),
                      offset: const Offset(0.03, 0),
                      child: _VehicleRow(
                        vehicle: vehicle,
                        layout: layout,
                        busy: deleting.contains(vehicle.id),
                        onEdit: () => onEdit(vehicle),
                        onDelete: () => onDelete(vehicle),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              if (layout != _TableLayout.compact) ...[
                _HeaderRow(layout: layout),
                const Divider(),
              ],
              ...rows,
              AnimatedCollapse(
                visible: visibleCount == 0,
                child: _EmptyState(
                  hasVehicles: hasVehicles,
                  onClearFilters: onClearFilters,
                  onRegister: onRegister,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Column proportions shared by the header and the rows.
const _numberFlex = 3;
const _companyFlex = 3;
const _typeFlex = 2;
const _brandFlex = 2;
const _modelFlex = 2;
const _statusFlex = 4;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.layout});

  final _TableLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );
    Widget cell(String text, int flex) => Expanded(
      flex: flex,
      child: Text(text.toUpperCase(), style: style),
    );
    final full = layout == _TableLayout.full;

    return Container(
      color: AppColors.tableHeader,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg + 4,
        AppSpacing.md - 2,
        AppSpacing.lg,
        AppSpacing.md - 2,
      ),
      child: ExcludeSemantics(
        child: Row(
          children: [
            cell('Vehicle number', _numberFlex),
            if (full) ...[
              cell('Company', _companyFlex),
              cell('Type', _typeFlex),
              cell('Brand', _brandFlex),
              cell('Model', _modelFlex),
            ] else ...[
              cell('Vehicle', _brandFlex + _modelFlex + _companyFlex),
            ],
            cell('Status', _statusFlex),
            SizedBox(width: _actionsWidth(layout)),
          ],
        ),
      ),
    );
  }
}

class _VehicleRow extends StatefulWidget {
  const _VehicleRow({
    required this.vehicle,
    required this.layout,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final Vehicle vehicle;
  final _TableLayout layout;

  /// A delete request for this row is in flight.
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_VehicleRow> createState() => _VehicleRowState();
}

class _VehicleRowState extends State<_VehicleRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final v = widget.vehicle;
    final layout = widget.layout;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final typeLabel = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(vehicleTypeIcon(v.type), size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(v.type, overflow: TextOverflow.ellipsis)),
      ],
    );

    final Widget actions;
    if (widget.busy) {
      actions = Semantics(
        liveRegion: true,
        label: 'Deleting ${v.vehicleNumber}',
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.error,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Deleting…',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (layout == _TableLayout.full || layout == _TableLayout.compact) {
      actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: widget.onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
          const SizedBox(width: AppSpacing.xs),
          TextButton.icon(
            onPressed: widget.onDelete,
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
          ),
        ],
      );
    } else {
      actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Edit ${v.vehicleNumber}',
            onPressed: widget.onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete ${v.vehicleNumber}',
            onPressed: widget.onDelete,
            color: scheme.error,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      );
    }

    final Widget content;
    switch (layout) {
      case _TableLayout.compact:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(child: VehicleNumberBadge(number: v.vehicleNumber)),
                const Spacer(),
                VehicleStatusChip(status: v.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Text(v.displayName, style: theme.textTheme.titleSmall),
            Text('${v.company} · ${v.type}', style: muted),
            const SizedBox(height: AppSpacing.xs),
            Align(alignment: Alignment.centerRight, child: actions),
          ],
        );
      case _TableLayout.medium:
        content = Row(
          children: [
            Expanded(
              flex: _numberFlex,
              child: Align(
                alignment: Alignment.centerLeft,
                child: VehicleNumberBadge(number: v.vehicleNumber),
              ),
            ),
            Expanded(
              flex: _brandFlex + _modelFlex + _companyFlex,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.displayName, style: theme.textTheme.titleSmall),
                  Text('${v.company} · ${v.type}', style: muted),
                ],
              ),
            ),
            Expanded(
              flex: _statusFlex,
              child: Align(
                alignment: Alignment.centerLeft,
                child: VehicleStatusChip(status: v.status),
              ),
            ),
            SizedBox(
              width: _actionsWidth(layout),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: actions,
              ),
            ),
          ],
        );
      case _TableLayout.full:
        content = Row(
          children: [
            Expanded(
              flex: _numberFlex,
              child: Align(
                alignment: Alignment.centerLeft,
                child: VehicleNumberBadge(number: v.vehicleNumber),
              ),
            ),
            Expanded(flex: _companyFlex, child: Text(v.company)),
            Expanded(flex: _typeFlex, child: typeLabel),
            Expanded(
              flex: _brandFlex,
              child: Text(v.brand, style: theme.textTheme.titleSmall),
            ),
            Expanded(flex: _modelFlex, child: Text(v.model)),
            Expanded(
              flex: _statusFlex,
              child: Align(
                alignment: Alignment.centerLeft,
                child: VehicleStatusChip(status: v.status),
              ),
            ),
            SizedBox(
              width: _actionsWidth(layout),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: actions,
              ),
            ),
          ],
        );
    }

    return Semantics(
      container: true,
      label:
          '${v.vehicleNumber}, ${v.displayName}, ${v.type}, '
          '${v.company}, status ${v.status.label}',
      child: InkWell(
        onTap: widget.busy ? null : widget.onEdit,
        onHover: (value) => setState(() => _hovered = value),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: vehicleStatusColor(v.status), width: 4),
            ),
          ),
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.fromLTRB(
              _hovered ? AppSpacing.xl : AppSpacing.lg,
              AppSpacing.sm + 2,
              AppSpacing.lg,
              AppSpacing.sm + 2,
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: widget.busy ? 0.55 : 1,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
