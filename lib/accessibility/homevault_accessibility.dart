import 'package:flutter/material.dart';

class HomeVaultAccessibility {
  const HomeVaultAccessibility._();

  static const double minimumTouchTarget = 48;
  static const double largeTextThreshold = 1.3;
  static const double veryLargeTextThreshold = 1.7;

  static double textScaleOf(BuildContext context) {
    return MediaQuery.textScalerOf(context).scale(1);
  }

  static int responsiveColumnCount({
    required double availableWidth,
    required double textScale,
  }) {
    if (textScale >= veryLargeTextThreshold || availableWidth < 340) {
      return 1;
    }

    if (textScale >= largeTextThreshold || availableWidth < 600) {
      return 2;
    }

    return 4;
  }

  static String countLabel(String label, int count) {
    return '$label: $count';
  }
}
