import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P19 Phase 1 establishes global accessible interaction defaults', () {
    final theme = File('lib/theme/app_theme.dart').readAsStringSync();

    expect(
      theme,
      contains('materialTapTargetSize: MaterialTapTargetSize.padded'),
    );
    expect(theme, contains('visualDensity: VisualDensity.standard'));
    expect(theme, contains('minimumSize: const Size(48, 48)'));
    expect(
      theme,
      contains('minimumSize: WidgetStatePropertyAll(Size.square(48))'),
    );
  });

  test(
    'dashboard adapts metrics for large text and exposes useful semantics',
    () {
      final dashboard = File(
        'lib/screens/dashboard/dashboard_screen.dart',
      ).readAsStringSync();

      expect(
        dashboard,
        contains('HomeVaultAccessibility.responsiveColumnCount'),
      );
      expect(
        dashboard,
        contains('HomeVaultAccessibility.textScaleOf(context)'),
      );
      expect(dashboard, isNot(contains('height: 94')));
      expect(dashboard, contains("label: '\$label: \$value'"));
      expect(dashboard, contains('button: true'));
      expect(dashboard, contains('Reminder center, no items need attention'));
      expect(dashboard, contains('header: true'));
    },
  );

  test('shared cards and empty states provide semantic structure', () {
    final quickAction = File(
      'lib/widgets/quick_action_tile.dart',
    ).readAsStringSync();
    final dashboardCard = File(
      'lib/widgets/dashboard_card.dart',
    ).readAsStringSync();
    final emptyState = File('lib/widgets/empty_state.dart').readAsStringSync();
    final app = File('lib/app.dart').readAsStringSync();

    expect(quickAction, contains('Semantics('));
    expect(quickAction, contains('button: true'));
    expect(quickAction, contains('label: title'));

    expect(dashboardCard, contains("label: '\$title: \$value'"));
    expect(dashboardCard, isNot(contains('TextOverflow.ellipsis')));

    expect(emptyState, contains('header: true'));
    expect(app, contains('liveRegion: true'));
  });
}
