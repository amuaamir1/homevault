import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/theme/app_theme.dart';
import 'package:homevault/widgets/dashboard_card.dart';
import 'package:homevault/widgets/quick_action_tile.dart';

void main() {
  testWidgets('global IconButton touch target is at least 48 by 48', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: IconButton(
            tooltip: 'Test action',
            onPressed: () {},
            icon: const Icon(Icons.add),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('QuickActionTile remains usable with large text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SizedBox(
              width: 180,
              child: QuickActionTile(
                icon: Icons.description_outlined,
                title: 'Open important documents',
                onTap: () {},
                color: Colors.blue,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Open important documents'), findsOneWidget);
  });

  testWidgets('DashboardCard does not truncate its accessible title', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SizedBox(
              width: 220,
              child: DashboardCard(
                icon: Icons.description_outlined,
                title: 'Documents that need your attention',
                value: '12',
                color: Colors.blue,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Documents that need your attention'), findsOneWidget);
  });
}
