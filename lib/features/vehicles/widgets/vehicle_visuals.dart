import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../models/vehicle.dart';

IconData vehicleTypeIcon(VehicleType type) {
  switch (type) {
    case VehicleType.car:
      return Icons.directions_car_outlined;
    case VehicleType.van:
      return Icons.airport_shuttle_outlined;
    case VehicleType.truck:
      return Icons.local_shipping_outlined;
    case VehicleType.trailer:
      return Icons.rv_hookup_outlined;
    case VehicleType.forklift:
      return Icons.precision_manufacturing_outlined;
  }
}

Color vehicleStatusColor(VehicleStatus status) {
  switch (status) {
    case VehicleStatus.available:
      return AppColors.success;
    case VehicleStatus.inUse:
      return AppColors.info;
    case VehicleStatus.maintenance:
      return AppColors.warning;
    case VehicleStatus.retired:
      return AppColors.neutral;
  }
}

/// Highlighted identifier so the vehicle number is the first thing you see.
class VehicleNumberBadge extends StatelessWidget {
  const VehicleNumberBadge({super.key, required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: AppColors.navyTint,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        number,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          fontSize: 13.5,
        ),
      ),
    );
  }
}

class VehicleStatusChip extends StatelessWidget {
  const VehicleStatusChip({super.key, required this.status});

  final VehicleStatus status;

  @override
  Widget build(BuildContext context) {
    final color = vehicleStatusColor(status);
    return Semantics(
      label: 'Status: ${status.label}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.xs + 1,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm - 2),
            Flexible(
              child: Text(
                status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
