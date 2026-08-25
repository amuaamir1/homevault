import 'package:flutter/material.dart';

import '../models/appliance.dart';
import '../theme/app_colors.dart';

class WarrantyStatusChip extends StatelessWidget {
  const WarrantyStatusChip({super.key, required this.status});

  final WarrantyStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      WarrantyStatus.active => (
        'Active',
        AppColors.success,
        Icons.verified_outlined,
      ),
      WarrantyStatus.expiringSoon => (
        'Expiring soon',
        AppColors.warning,
        Icons.warning_amber_outlined,
      ),
      WarrantyStatus.expired => (
        'Expired',
        AppColors.danger,
        Icons.cancel_outlined,
      ),
      WarrantyStatus.notProvided => (
        'No warranty date',
        AppColors.textSecondary,
        Icons.help_outline,
      ),
    };

    return Semantics(
      container: true,
      label: 'Warranty status: $label',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
