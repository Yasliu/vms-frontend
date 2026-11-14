import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/animated_collapse.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/form_section.dart';
import '../../core/widgets/page_header.dart';
import '../../data/mock_vehicles.dart';
import '../../data/vehicle_repository.dart';
import '../../models/vehicle.dart';
import 'widgets/vehicle_visuals.dart';

/// Used for both registering a new vehicle and editing an existing one.
class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key, this.vehicle});

  final Vehicle? vehicle;

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  static final _numberPattern = RegExp(r'^[A-Z0-9][A-Z0-9 \-]{1,11}$');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  String? _company;
  VehicleType? _type;
  late VehicleStatus _status;
  bool _saving = false;
  bool _showErrorSummary = false;

  bool get _isEdit => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _number = TextEditingController(text: v?.vehicleNumber);
    _brand = TextEditingController(text: v?.brand);
    _model = TextEditingController(text: v?.model);
    _company = v?.company;
    _type = v?.type;
    _status = v?.status ?? VehicleStatus.available;
  }

  @override
  void dispose() {
    _number.dispose();
    _brand.dispose();
    _model.dispose();
    super.dispose();
  }

  String? _validateNumber(String? value) {
    final text = (value ?? '').trim().toUpperCase();
    if (text.isEmpty) return 'Enter the vehicle number, for example AB 12345.';
    if (!_numberPattern.hasMatch(text)) {
      return 'Use 2–12 letters, numbers, spaces or hyphens.';
    }
    if (VehicleRepository.instance.isNumberTaken(
      text,
      exceptId: widget.vehicle?.id,
    )) {
      return 'This vehicle number is already registered.';
    }
    return null;
  }

  String? Function(String?) _validateText(String field, String example) {
    return (value) {
      final text = (value ?? '').trim();
      if (text.isEmpty) {
        return 'Enter the vehicle $field, for example $example.';
      }
      if (text.length > 40) return 'Keep the $field under 40 characters.';
      return null;
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _showErrorSummary = true);
      return;
    }
    setState(() {
      _showErrorSummary = false;
      _saving = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final repository = VehicleRepository.instance;
    final vehicle = Vehicle(
      id: widget.vehicle?.id ?? repository.nextId(),
      vehicleNumber: _number.text.trim().toUpperCase(),
      company: _company!,
      type: _type!,
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      status: _status,
    );
    if (_isEdit) {
      repository.update(vehicle);
    } else {
      repository.add(vehicle);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEdit
              ? '${vehicle.vehicleNumber} updated'
              : '${vehicle.vehicleNumber} registered',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return ListView(
      padding: EdgeInsets.all(Breakpoints.pagePadding(width)),
      children: [
        FadeSlideIn(
          child: PageHeader(
            title: _isEdit ? 'Edit vehicle' : 'Register vehicle',
            subtitle: _isEdit
                ? 'Update the details for ${widget.vehicle!.vehicleNumber}'
                : 'Add a new vehicle to your fleet',
            leading: IconButton.filledTonal(
              tooltip: 'Back to vehicles',
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: _buildContent(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedCollapse(
          visible: _showErrorSummary,
          child: Container(
            color: scheme.errorContainer,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md - 4,
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      'Some fields need your attention. Check the highlighted '
                      'fields below.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _section(
          0,
          FormSection(
            title: 'Identification',
            description: 'How this vehicle is identified and who owns it.',
            child: FieldGrid(
              children: [
                TextFormField(
                  controller: _number,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[A-Za-z0-9 \-]'),
                    ),
                    LengthLimitingTextInputFormatter(12),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Vehicle number *',
                    hintText: 'AB 12345',
                    helperText: 'Letters, numbers, spaces or hyphens',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                  validator: _validateNumber,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _company,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Company *',
                    helperText: 'The company that owns the vehicle',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  hint: const Text('Select a company'),
                  items: [
                    for (final c in mockCompanies)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (value) => setState(() => _company = value),
                  validator: (value) =>
                      value == null ? 'Select the company that owns it.' : null,
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        _section(
          1,
          FormSection(
            title: 'Vehicle details',
            description: 'Type, brand and model as shown in the registration.',
            child: FieldGrid(
              children: [
                DropdownButtonFormField<VehicleType>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Type *',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  hint: const Text('Select a vehicle type'),
                  items: [
                    for (final t in VehicleType.values)
                      DropdownMenuItem(
                        value: t,
                        child: Row(
                          children: [
                            Icon(vehicleTypeIcon(t), size: 18),
                            const SizedBox(width: AppSpacing.sm + 2),
                            Text(t.label),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _type = value),
                  validator: (value) =>
                      value == null ? 'Select the vehicle type.' : null,
                ),
                TextFormField(
                  controller: _brand,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Brand *',
                    hintText: 'Volvo',
                  ),
                  validator: _validateText('brand', 'Volvo'),
                ),
                TextFormField(
                  controller: _model,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Model *',
                    hintText: 'FH16',
                  ),
                  validator: _validateText('model', 'FH16'),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        _section(
          2,
          FormSection(
            title: 'Status',
            description: 'The current operational state of the vehicle.',
            child: _StatusPicker(
              value: _status,
              onChanged: (value) => setState(() => _status = value),
            ),
          ),
        ),
        const Divider(),
        _buildActions(context),
      ],
    );
  }

  Widget _section(int index, Widget child) => FadeSlideIn(
    delay: Duration(milliseconds: 150 + 90 * index),
    child: child,
  );

  Widget _buildActions(BuildContext context) {
    final theme = Theme.of(context);

    final cancel = AppButton(
      label: 'Cancel',
      variant: AppButtonVariant.outlined,
      expand: MediaQuery.sizeOf(context).width < 480,
      onPressed: _saving ? null : () => Navigator.of(context).pop(),
    );
    final save = AppButton(
      label: _isEdit ? 'Save changes' : 'Register vehicle',
      icon: Icons.check,
      isLoading: _saving,
      expand: MediaQuery.sizeOf(context).width < 480,
      onPressed: _save,
    );

    return Container(
      color: AppColors.tableHeader,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 480) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                save,
                const SizedBox(height: AppSpacing.sm + 4),
                cancel,
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Text(
                  '* Required field',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              cancel,
              const SizedBox(width: AppSpacing.sm + 4),
              save,
            ],
          );
        },
      ),
    );
  }
}

class _StatusPicker extends StatelessWidget {
  const _StatusPicker({required this.value, required this.onChanged});

  final VehicleStatus value;
  final ValueChanged<VehicleStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Vehicle status',
      child: Wrap(
        spacing: AppSpacing.sm + 4,
        runSpacing: AppSpacing.sm + 4,
        children: [
          for (final status in VehicleStatus.values)
            ChoiceChip(
              showCheckmark: false,
              selected: value == status,
              onSelected: (_) => onChanged(status),
              avatar: Icon(
                value == status ? Icons.check_circle : Icons.circle,
                size: 16,
                color: vehicleStatusColor(status),
              ),
              label: Text(status.label),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
            ),
        ],
      ),
    );
  }
}
