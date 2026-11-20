import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/animated_collapse.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/form_section.dart';
import '../../core/widgets/page_header.dart';
import '../../core/network/api_exception.dart';
import '../../models/vehicle.dart';
import 'vehicle_scope.dart';
import 'widgets/vehicle_visuals.dart';

/// Used for both registering a new vehicle and editing an existing one.
class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key, this.vehicle});

  final Vehicle? vehicle;

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  // Same limits as the backend's request validation.
  static const _maxNumber = 30;
  static const _maxCompany = 100;
  static const _maxShort = 50;

  static const _fieldsShown = {
    'vehicleNumber',
    'company',
    'type',
    'brand',
    'model',
  };

  static const _typeSuggestions = [
    'Car',
    'Van',
    'Truck',
    'Trailer',
    'Forklift',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _company;
  late final TextEditingController _type;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late VehicleStatus _status;
  bool _saving = false;
  bool _showErrorSummary = false;

  // Problems reported by the server, shown until the field is edited.
  Map<String, String> _serverErrors = {};
  String? _submitError;

  bool get _isEdit => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _number = TextEditingController(text: v?.vehicleNumber);
    _company = TextEditingController(text: v?.company);
    _type = TextEditingController(text: v?.type);
    _brand = TextEditingController(text: v?.brand);
    _model = TextEditingController(text: v?.model);
    _status = v?.status ?? VehicleStatus.active;
  }

  @override
  void dispose() {
    _number.dispose();
    _company.dispose();
    _type.dispose();
    _brand.dispose();
    _model.dispose();
    super.dispose();
  }

  /// Required + max length, then any message the server gave for this field.
  String? Function(String?) _validator(
    String field,
    String label,
    int max, {
    String? example,
  }) {
    return (value) {
      final text = (value ?? '').trim();
      if (text.isEmpty) {
        return example == null
            ? 'Enter the $label.'
            : 'Enter the $label, for example $example.';
      }
      if (text.length > max) {
        return 'Use $max characters or fewer for the $label.';
      }
      return _serverErrors[field];
    };
  }

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field) || _submitError != null) {
      setState(() {
        _serverErrors = {..._serverErrors}..remove(field);
        _submitError = null;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _serverErrors = {};
      _submitError = null;
    });
    if (!_formKey.currentState!.validate()) {
      setState(() => _showErrorSummary = true);
      return;
    }
    setState(() {
      _showErrorSummary = false;
      _saving = true;
    });

    final controller = VehicleScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final input = VehicleInput(
      // The server normalizes the number (case, spacing); the form just trims.
      vehicleNumber: _number.text.trim(),
      company: _company.text.trim(),
      type: _type.text.trim(),
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      status: _status,
    );

    try {
      final saved = _isEdit
          ? await controller.update(widget.vehicle!.id, input)
          : await controller.create(input);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? '${saved.vehicleNumber} updated'
                : '${saved.vehicleNumber} registered',
          ),
        ),
      );
      navigator.pop();
    } on ApiException catch (e) {
      // The vehicle was deleted elsewhere: the list we hold is stale.
      if (_isEdit && e.kind == ApiErrorKind.notFound) controller.load();
      if (!mounted) return;
      // Field errors appear under their fields; anything else (or a field
      // this form does not show) goes in the banner.
      final elsewhere = e.fieldErrors.entries
          .where((entry) => !_fieldsShown.contains(entry.key))
          .map((entry) => entry.value);
      final onFields = e.fieldErrors.keys.any(_fieldsShown.contains);
      setState(() {
        _saving = false;
        _serverErrors = e.fieldErrors;
        _submitError = e.fieldErrors.isEmpty
            ? e.message
            : (elsewhere.isEmpty ? null : elsewhere.join(' '));
        _showErrorSummary = onFields;
      });
      if (onFields) _formKey.currentState!.validate();
    }
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
          visible: _submitError != null,
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
                      'Could not save the vehicle. ${_submitError ?? ''}',
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
                    LengthLimitingTextInputFormatter(_maxNumber),
                  ],
                  onChanged: (_) => _clearServerError('vehicleNumber'),
                  decoration: const InputDecoration(
                    labelText: 'Vehicle number *',
                    hintText: 'AB 12345',
                    helperText: 'Must be unique',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                  validator: _validator(
                    'vehicleNumber',
                    'vehicle number',
                    _maxNumber,
                    example: 'AB 12345',
                  ),
                ),
                TextFormField(
                  controller: _company,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_maxCompany),
                  ],
                  onChanged: (_) => _clearServerError('company'),
                  decoration: const InputDecoration(
                    labelText: 'Company *',
                    helperText: 'The company that owns the vehicle',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  validator: _validator('company', 'company', _maxCompany),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _type,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(_maxShort),
                      ],
                      onChanged: (_) => _clearServerError('type'),
                      decoration: const InputDecoration(
                        labelText: 'Type *',
                        hintText: 'Truck',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      validator: _validator('type', 'type', _maxShort),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final t in _typeSuggestions)
                          ActionChip(
                            avatar: Icon(vehicleTypeIcon(t), size: 16),
                            label: Text(t),
                            onPressed: () {
                              _type.text = t;
                              _clearServerError('type');
                            },
                          ),
                      ],
                    ),
                  ],
                ),
                TextFormField(
                  controller: _brand,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_maxShort),
                  ],
                  onChanged: (_) => _clearServerError('brand'),
                  decoration: const InputDecoration(
                    labelText: 'Brand *',
                    hintText: 'Volvo',
                  ),
                  validator: _validator(
                    'brand',
                    'brand',
                    _maxShort,
                    example: 'Volvo',
                  ),
                ),
                TextFormField(
                  controller: _model,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_maxShort),
                  ],
                  onChanged: (_) => _clearServerError('model'),
                  decoration: const InputDecoration(
                    labelText: 'Model *',
                    hintText: 'FH16',
                  ),
                  validator: _validator(
                    'model',
                    'model',
                    _maxShort,
                    example: 'FH16',
                  ),
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
