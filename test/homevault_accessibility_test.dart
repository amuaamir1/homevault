import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/accessibility/homevault_accessibility.dart';
import 'package:homevault/theme/app_colors.dart';

void main() {
  test('metric layout expands across the P19 Phase 4 scale matrix', () {
    expect(
      HomeVaultAccessibility.responsiveColumnCount(
        availableWidth: 720,
        textScale: 1,
      ),
      4,
    );
    expect(
      HomeVaultAccessibility.responsiveColumnCount(
        availableWidth: 390,
        textScale: 1,
      ),
      2,
    );
    expect(
      HomeVaultAccessibility.responsiveColumnCount(
        availableWidth: 720,
        textScale: 1.3,
      ),
      2,
    );
    expect(
      HomeVaultAccessibility.responsiveColumnCount(
        availableWidth: 720,
        textScale: 1.7,
      ),
      1,
    );
    expect(
      HomeVaultAccessibility.responsiveColumnCount(
        availableWidth: 390,
        textScale: 2,
      ),
      1,
    );
    expect(
      HomeVaultAccessibility.responsiveColumnCount(
        availableWidth: 720,
        textScale: 1,
        maxColumns: 3,
      ),
      3,
    );
  });

  test('count labels include both meaning and value', () {
    expect(HomeVaultAccessibility.countLabel('Documents', 4), 'Documents: 4');
  });

  test('P19 light-theme text/status tokens meet deterministic AA contrast', () {
    const white = Colors.white;

    for (final color in <Color>[
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
      AppColors.danger,
      AppColors.textPrimary,
      AppColors.textSecondary,
    ]) {
      expect(
        HomeVaultAccessibility.contrastRatio(color, white),
        greaterThanOrEqualTo(4.5),
      );
    }

    expect(
      HomeVaultAccessibility.contrastRatio(
        AppColors.textSecondary,
        AppColors.background,
      ),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('status text remains AA-readable on its strongest common tint', () {
    for (final color in <Color>[
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
      AppColors.danger,
      AppColors.textSecondary,
    ]) {
      final tintedBackground = HomeVaultAccessibility.blendOver(
        color,
        Colors.white,
        opacity: 0.14,
      );
      expect(
        HomeVaultAccessibility.contrastRatio(color, tintedBackground),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}
