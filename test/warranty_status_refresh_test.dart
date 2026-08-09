import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/screens/appliances/add_appliance_screen.dart';

void main() {
  testWidgets(
    'editing warranty duration clears a stale out-of-warranty override',
    (tester) async {
      final now = DateTime.now();
      final purchaseDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 30));

      final appliance = Appliance(
        id: 'warranty-refresh-1',
        name: 'Test appliance',
        category: 'Other',
        brand: 'Test',
        purchaseDate: purchaseDate,
        warrantyExpiryDate: Appliance.calculateWarrantyExpiryDate(
          startDate: purchaseDate,
          durationValue: 1,
          durationUnit: WarrantyDurationUnit.years,
        ),
        warrantyDurationValue: 1,
        warrantyDurationUnit: WarrantyDurationUnit.years,
        warrantyMarkedExpired: true,
        createdAt: purchaseDate,
      );

      await tester.pumpWidget(
        MaterialApp(home: AddApplianceScreen(appliance: appliance)),
      );
      await tester.pumpAndSettle();

      final listView = find.byType(ListView);
      expect(listView, findsOneWidget);

      final switchFinder = find.byKey(
        const ValueKey('warrantyMarkedExpiredSwitch'),
      );
      final durationFinder = find.byKey(
        const ValueKey('warrantyDurationValueField'),
      );

      // AddApplianceScreen uses a lazy ListView. The switch is far below the
      // initial viewport, so scroll it into the widget tree before asserting.
      await tester.dragUntilVisible(
        switchFinder,
        listView,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      expect(switchFinder, findsOneWidget);
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);

      // Return to the duration field and change the warranty so its calculated
      // expiry remains in the future.
      await tester.dragUntilVisible(
        durationFinder,
        listView,
        const Offset(0, 500),
      );
      await tester.pumpAndSettle();

      expect(durationFinder, findsOneWidget);
      await tester.enterText(durationFinder, '4');
      await tester.pump();

      // Scroll back to the manual override and verify that the stale flag was
      // cleared by the edit.
      await tester.dragUntilVisible(
        switchFinder,
        listView,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
    },
  );

  testWidgets('new appliance defaults warranty duration unit to Year', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddApplianceScreen()));
    await tester.pumpAndSettle();

    final listView = find.byType(ListView);
    final unitFinder = find.byKey(const ValueKey('warrantyDurationUnitField'));

    await tester.dragUntilVisible(unitFinder, listView, const Offset(0, -450));
    await tester.pumpAndSettle();

    expect(unitFinder, findsOneWidget);
    expect(find.text('Year'), findsOneWidget);

    final dropdown = tester
        .widget<DropdownButtonFormField<WarrantyDurationUnit>>(unitFinder);
    expect(dropdown.initialValue, WarrantyDurationUnit.years);

    await tester.tap(unitFinder);
    await tester.pumpAndSettle();

    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Year'), findsWidgets);
    expect(find.text('Months'), findsNothing);
    expect(find.text('Years'), findsNothing);
  });

  testWidgets(
    'month-based warranty stays editable in automatic calculation mode',
    (tester) async {
      final appliance = Appliance(
        id: 'month-warranty-1',
        name: 'Washing machine',
        category: 'Laundry',
        brand: 'Bosch',
        purchaseDate: DateTime(2026, 8, 8),
        warrantyExpiryDate: DateTime(2028, 2, 7),
        warrantyDurationValue: 18,
        warrantyDurationUnit: WarrantyDurationUnit.months,
        createdAt: DateTime(2026, 8, 8),
      );

      await tester.pumpWidget(
        MaterialApp(home: AddApplianceScreen(appliance: appliance)),
      );
      await tester.pumpAndSettle();

      final listView = find.byType(ListView);
      final durationFinder = find.byKey(
        const ValueKey('warrantyDurationValueField'),
      );
      final unitFinder = find.byKey(
        const ValueKey('warrantyDurationUnitField'),
      );

      // ListView lazily builds and disposes off-screen children. Check the
      // duration field while it is visible before scrolling farther down to
      // the unit selector.
      await tester.dragUntilVisible(
        durationFinder,
        listView,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      expect(durationFinder, findsOneWidget);
      expect(
        tester.widget<TextFormField>(durationFinder).controller?.text,
        '18',
      );

      await tester.dragUntilVisible(
        unitFinder,
        listView,
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();

      expect(unitFinder, findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.text('07/02/2028'), findsOneWidget);
    },
  );

  test('future calculated warranty is active when override is cleared', () {
    final appliance = Appliance(
      id: 'active-1',
      name: 'Active appliance',
      category: 'Other',
      brand: 'Test',
      warrantyExpiryDate: DateTime(2030, 7, 31),
      warrantyMarkedExpired: false,
      createdAt: DateTime(2024, 8, 1),
    );

    expect(
      appliance.warrantyStatusAt(DateTime(2026, 8, 8)),
      WarrantyStatus.active,
    );
  });
}
