import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/animated_collapse.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/page_header.dart';
import '../../data/vehicle_repository.dart';
import '../../models/vehicle.dart';
import 'widgets/vehicle_visuals.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  final _repository = VehicleRepository.instance;
  final _searchController = TextEditingController();
  String _query = '';
  VehicleStatus? _statusFilter;

  // Rows that were deleted and are currently animating out.
  final _removing = <String>{};
  // False during the first build so existing rows use the staggered intro;
  // rows added later grow into place instead.
  bool _initialized = false;

  bool get _hasFilters => _query.trim().isNotEmpty || _statusFilter != null;

  @override
  void initState() {
    super.initState();
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
        v.type.label.toLowerCase().contains(q);
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

    setState(() => _removing.add(vehicle.id));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${vehicle.vehicleNumber} deleted')));
    // Let the row collapse before it is removed from the data.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _repository.remove(vehicle.id);
    _removing.remove(vehicle.id);
  }

  void _edit(Vehicle vehicle) {
    Navigator.of(context).pushNamed(AppRoutes.vehicleEdit, arguments: vehicle);
  }

  void _register() => Navigator.of(context).pushNamed(AppRoutes.vehicleNew);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return ValueListenableBuilder<List<Vehicle>>(
      valueListenable: _repository.vehicles,
      builder: (context, all, _) {
        final current = all.where((v) => !_removing.contains(v.id)).toList();
        final visibleCount = all.where(_isVisible).length;

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
            ),
            const SizedBox(height: AppSpacing.sm),
            _VehicleTable(
              vehicles: all,
              isVisible: _isVisible,
              animateIn: _initialized,
              hasVehicles: current.isNotEmpty,
              onEdit: _edit,
              onDelete: _confirmDelete,
              onClearFilters: _clearFilters,
              onRegister: _register,
            ),
          ],
        );
      },
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
        'Available',
        count(VehicleStatus.available),
        Icons.check_circle_outline,
        vehicleStatusColor(VehicleStatus.available),
      ),
      (
        'In use',
        count(VehicleStatus.inUse),
        Icons.route_outlined,
        vehicleStatusColor(VehicleStatus.inUse),
      ),
      (
        'Maintenance',
        count(VehicleStatus.maintenance),
        Icons.build_outlined,
        vehicleStatusColor(VehicleStatus.maintenance),
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
  });

  final int shown;
  final int total;
  final bool showClear;
  final VoidCallback onClear;

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
    required this.animateIn,
    required this.hasVehicles,
    required this.onEdit,
    required this.onDelete,
    required this.onClearFilters,
    required this.onRegister,
  });

  final List<Vehicle> vehicles;
  final bool Function(Vehicle) isVisible;
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
    required this.onEdit,
    required this.onDelete,
  });

  final Vehicle vehicle;
  final _TableLayout layout;
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
        Flexible(child: Text(v.type.label, overflow: TextOverflow.ellipsis)),
      ],
    );

    final Widget actions;
    if (layout == _TableLayout.full || layout == _TableLayout.compact) {
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
            Text('${v.company} · ${v.type.label}', style: muted),
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
                  Text('${v.company} · ${v.type.label}', style: muted),
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
          '${v.vehicleNumber}, ${v.displayName}, ${v.type.label}, '
          '${v.company}, status ${v.status.label}',
      child: InkWell(
        onTap: widget.onEdit,
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
            child: content,
          ),
        ),
      ),
    );
  }
}
