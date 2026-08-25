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

  static String contextualAction(String action, String context) {
    final normalizedContext = context.trim();
    return normalizedContext.isEmpty
        ? action
        : '$action for $normalizedContext';
  }
}

/// A silent visual marker that announces only meaningful status changes.
///
/// Keeping the announcement in its own semantics node prevents progress
/// indicators and repeated visible status text from being spoken twice.
class HomeVaultStatusAnnouncement extends StatelessWidget {
  const HomeVaultStatusAnnouncement({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: const ExcludeSemantics(child: SizedBox.shrink()),
    );
  }
}

/// Adds heading navigation without replacing the visible text's accessible
/// name or creating a second spoken node.
class HomeVaultSectionHeading extends StatelessWidget {
  const HomeVaultSectionHeading({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(header: true, child: child);
  }
}
