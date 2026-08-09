import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/service_record.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/state/app_scope.dart';
import 'package:homevault/state/appliance_store.dart';
import 'package:homevault/screens/appliances/appliances_screen.dart';

Future<ApplianceStore> _pumpAppliances(
  WidgetTester tester,
  List<Appliance> appliances,
) async {
  final store = ApplianceStore(
    repository: MemoryApplianceRepository(initialAppliances: appliances),
  );
  await store.initialize();

  await tester.pumpWidget(
    AppScope(
      applianceStore: store,
      child: MaterialApp(home: AppliancesScreen(onAddAppliance: () async {})),
    ),
  );
  await tester.pumpAndSettle();

  return store;
}

Appliance _appliance({
  required String id,
  required String name,
  required String category,
  required String brand,
  required DateTime createdAt,
  String modelNumber = '',
  String serialNumber = '',
  DateTime? warrantyExpiryDate,
  String supportProvider = '',
  List<ServiceRecord> serviceRecords = const [],
}) {
  return Appliance(
    id: id,
    name: name,
    category: category,
    brand: brand,
    modelNumber: modelNumber,
    serialNumber: serialNumber,
    warrantyExpiryDate: warrantyExpiryDate,
    supportProvider: supportProvider,
    serviceRecords: serviceRecords,
    createdAt: createdAt,
  );
}

void main() {
  testWidgets('search matches multiple terms across appliance details', (
    tester,
  ) async {
    final now = DateTime.now();
    final store = await _pumpAppliances(tester, [
      _appliance(
        id: 'ac-1',
        name: 'Living room AC',
        category: 'Air Conditioner',
        brand: 'Samsung',
        modelNumber: 'AR18',
        serialNumber: 'SN-200',
        supportProvider: 'CoolCare',
        createdAt: now.subtract(const Duration(days: 10)),
        serviceRecords: [
          ServiceRecord(
            id: 'service-1',
            serviceDate: now.subtract(const Duration(days: 2)),
            createdAt: now.subtract(const Duration(days: 2)),
            provider: 'QuickFix',
            ticketNumber: 'JOB-42',
          ),
        ],
      ),
      _appliance(
        id: 'fridge-1',
        name: 'Kitchen fridge',
        category: 'Kitchen Appliance',
        brand: 'LG',
        modelNumber: 'GL500',
        serialNumber: 'FR-100',
        createdAt: now.subtract(const Duration(days: 20)),
      ),
    ]);
    addTearDown(store.dispose);

    final searchField = find.descendant(
      of: find.byKey(const ValueKey('applianceSearchField')),
      matching: find.byType(EditableText),
    );

    await tester.enterText(searchField, 'Samsung SN-200');
    await tester.pumpAndSettle();

    expect(find.text('Living room AC'), findsOneWidget);
    expect(find.text('Kitchen fridge'), findsNothing);
    expect(find.text('1 of 2 appliances across 1 category'), findsOneWidget);

    await tester.enterText(searchField, 'quickfix job-42');
    await tester.pumpAndSettle();

    expect(find.text('Living room AC'), findsOneWidget);
    expect(find.text('Kitchen fridge'), findsNothing);
  });

  testWidgets('category and warranty filters can be combined and cleared', (
    tester,
  ) async {
    final now = DateTime.now();
    final store = await _pumpAppliances(tester, [
      _appliance(
        id: 'ac-active',
        name: 'Bedroom AC',
        category: 'Air Conditioner',
        brand: 'Daikin',
        warrantyExpiryDate: now.add(const Duration(days: 365)),
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      _appliance(
        id: 'ac-expired',
        name: 'Study AC',
        category: 'Air Conditioner',
        brand: 'LG',
        warrantyExpiryDate: now.subtract(const Duration(days: 20)),
        createdAt: now.subtract(const Duration(days: 15)),
      ),
      _appliance(
        id: 'fridge-active',
        name: 'Kitchen fridge',
        category: 'Kitchen Appliance',
        brand: 'Samsung',
        warrantyExpiryDate: now.add(const Duration(days: 500)),
        createdAt: now.subtract(const Duration(days: 25)),
      ),
    ]);
    addTearDown(store.dispose);

    await tester.tap(find.byKey(const ValueKey('applianceFilterButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('applianceCategoryFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Air Conditioner').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('warrantyFilter-active')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('doneApplianceFiltersButton')));
    await tester.pumpAndSettle();

    expect(find.text('Bedroom AC'), findsOneWidget);
    expect(find.text('Study AC'), findsNothing);
    expect(find.text('Kitchen fridge'), findsNothing);
    expect(
      find.byKey(const ValueKey('activeCategoryFilterChip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('activeWarrantyFilterChip')),
      findsOneWidget,
    );
    expect(find.text('Filters (2)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('applianceFilterButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('resetApplianceFiltersButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('doneApplianceFiltersButton')));
    await tester.pumpAndSettle();

    expect(find.text('3 appliances across 2 categories'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('activeCategoryFilterChip')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('activeWarrantyFilterChip')),
      findsNothing,
    );

    // Clearing filters returns the screen to its normal grouped/collapsed
    // browsing state. Expand the categories before asserting their children.
    await tester.tap(find.text('Air Conditioner'));
    await tester.pumpAndSettle();

    expect(find.text('Bedroom AC'), findsOneWidget);
    expect(find.text('Study AC'), findsOneWidget);

    await tester.tap(find.text('Kitchen Appliance'));
    await tester.pumpAndSettle();

    expect(find.text('Kitchen fridge'), findsOneWidget);
  });

  testWidgets('sort changes appliance order inside a category', (tester) async {
    final now = DateTime.now();
    final store = await _pumpAppliances(tester, [
      _appliance(
        id: 'old',
        name: 'Alpha AC',
        category: 'Air Conditioner',
        brand: 'Brand A',
        createdAt: now.subtract(const Duration(days: 100)),
      ),
      _appliance(
        id: 'new',
        name: 'Zulu AC',
        category: 'Air Conditioner',
        brand: 'Brand Z',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
    addTearDown(store.dispose);

    await tester.tap(find.text('Air Conditioner'));
    await tester.pumpAndSettle();

    var alphaY = tester.getTopLeft(find.text('Alpha AC')).dy;
    var zuluY = tester.getTopLeft(find.text('Zulu AC')).dy;
    expect(alphaY, lessThan(zuluY));

    await tester.tap(find.byKey(const ValueKey('applianceSortButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Newest added'));
    await tester.pumpAndSettle();

    alphaY = tester.getTopLeft(find.text('Alpha AC')).dy;
    zuluY = tester.getTopLeft(find.text('Zulu AC')).dy;
    expect(zuluY, lessThan(alphaY));
  });
}
