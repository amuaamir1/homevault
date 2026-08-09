import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/service_record.dart';
import 'package:homevault/screens/service/add_service_record_screen.dart';
import 'package:homevault/screens/service/service_center_screen.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/services/homevault_report_service.dart';
import 'package:homevault/state/app_scope.dart';
import 'package:homevault/state/appliance_store.dart';

void main() {
  group('Maintenance schedule calculation', () {
    test('six-month interval calculates the example next service date', () {
      final nextService = ServiceRecord.calculateNextServiceDate(
        serviceDate: DateTime(2026, 2, 12),
        intervalValue: 6,
        intervalUnit: ServiceIntervalUnit.months,
      );

      expect(nextService, DateTime(2026, 8, 12));
    });

    test('year interval is supported', () {
      final nextService = ServiceRecord.calculateNextServiceDate(
        serviceDate: DateTime(2026, 8, 12),
        intervalValue: 1,
        intervalUnit: ServiceIntervalUnit.years,
      );

      expect(nextService, DateTime(2027, 8, 12));
    });

    test('month-end schedules clamp to a valid calendar date', () {
      final nextService = ServiceRecord.calculateNextServiceDate(
        serviceDate: DateTime(2026, 1, 31),
        intervalValue: 1,
        intervalUnit: ServiceIntervalUnit.months,
      );

      expect(nextService, DateTime(2026, 2, 28));
    });

    test('service interval survives JSON round trip', () {
      final original = ServiceRecord(
        id: 'service-1',
        serviceDate: DateTime(2026, 2, 12),
        createdAt: DateTime(2026, 2, 12),
        serviceIntervalValue: 6,
        serviceIntervalUnit: ServiceIntervalUnit.months,
        nextServiceDate: DateTime(2026, 8, 12),
      );

      final restored = ServiceRecord.fromJson(original.toJson());

      expect(restored.serviceIntervalValue, 6);
      expect(restored.serviceIntervalUnit, ServiceIntervalUnit.months);
      expect(restored.serviceFrequencyLabel, 'Every 6 months');
      expect(restored.nextServiceDate, DateTime(2026, 8, 12));
    });

    test('legacy service records remain compatible', () {
      final restored = ServiceRecord.fromJson({
        'id': 'legacy-service',
        'serviceDate': '2026-02-12T00:00:00.000',
        'createdAt': '2026-02-12T00:00:00.000',
        'nextServiceDate': '2026-08-12T00:00:00.000',
      });

      expect(restored.serviceIntervalValue, isNull);
      expect(restored.serviceFrequencyLabel, isNull);
      expect(restored.nextServiceDate, DateTime(2026, 8, 12));
    });
  });

  test('appliance maintenance schedule uses the newest scheduled record', () {
    final appliance = Appliance(
      id: 'ac-1',
      name: 'LG AC',
      category: 'Air Conditioner',
      brand: 'LG',
      serviceRecords: [
        ServiceRecord(
          id: 'old-service',
          serviceDate: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
          serviceIntervalValue: 6,
          nextServiceDate: DateTime(2026, 7, 1),
        ),
        ServiceRecord(
          id: 'latest-service',
          serviceDate: DateTime(2026, 2, 12),
          createdAt: DateTime(2026, 2, 12),
          serviceIntervalValue: 6,
          nextServiceDate: DateTime(2026, 8, 12),
        ),
      ],
      createdAt: DateTime(2025, 1, 1),
    );

    expect(appliance.lastServiceDate, DateTime(2026, 2, 12));
    expect(appliance.serviceFrequencyLabel, 'Every 6 months');
    expect(appliance.nextServiceDate, DateTime(2026, 8, 12));
  });

  test('reports include one proactive maintenance schedule per appliance', () {
    final referenceDate = DateTime(2026, 8, 1);
    final appliance = Appliance(
      id: 'ac-1',
      name: 'LG AC',
      category: 'Air Conditioner',
      brand: 'LG',
      serviceRecords: [
        ServiceRecord(
          id: 'old-service',
          serviceDate: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
          nextServiceDate: DateTime(2026, 8, 5),
        ),
        ServiceRecord(
          id: 'latest-service',
          serviceDate: DateTime(2026, 2, 12),
          createdAt: DateTime(2026, 2, 12),
          serviceIntervalValue: 6,
          nextServiceDate: DateTime(2026, 8, 12),
        ),
      ],
      createdAt: DateTime(2025, 1, 1),
    );

    final report = const HomeVaultReportService().build([
      appliance,
    ], now: referenceDate);

    expect(report.upcomingServices, hasLength(1));
    expect(report.upcomingServices.single.record.id, 'latest-service');
    expect(report.upcomingServices.single.daysRemaining, 11);
  });

  test(
    'upcoming service count counts an appliance schedule only once',
    () async {
      final referenceDate = DateTime(2026, 8, 1);
      final appliance = Appliance(
        id: 'ac-1',
        name: 'LG AC',
        category: 'Air Conditioner',
        brand: 'LG',
        serviceRecords: [
          ServiceRecord(
            id: 'old-service',
            serviceDate: DateTime(2026, 1, 1),
            createdAt: DateTime(2026, 1, 1),
            nextServiceDate: DateTime(2026, 8, 5),
          ),
          ServiceRecord(
            id: 'latest-service',
            serviceDate: DateTime(2026, 2, 12),
            createdAt: DateTime(2026, 2, 12),
            serviceIntervalValue: 6,
            nextServiceDate: DateTime(2026, 8, 12),
          ),
        ],
        createdAt: DateTime(2025, 1, 1),
      );
      final store = ApplianceStore(
        repository: MemoryApplianceRepository(initialAppliances: [appliance]),
      );
      await store.initialize();

      expect(store.upcomingServiceCount(days: 30, now: referenceDate), 1);

      store.dispose();
    },
  );

  testWidgets('service form shows interval and calculates schedule metadata', (
    tester,
  ) async {
    final appliance = Appliance(
      id: 'ac-1',
      name: 'LG AC',
      category: 'Air Conditioner',
      brand: 'LG',
      createdAt: DateTime(2025, 1, 1),
    );
    final record = ServiceRecord(
      id: 'service-1',
      serviceDate: DateTime(2026, 2, 12),
      createdAt: DateTime(2026, 2, 12),
      problemDescription: 'Routine maintenance',
      serviceIntervalValue: 6,
      serviceIntervalUnit: ServiceIntervalUnit.months,
      nextServiceDate: DateTime(2026, 8, 12),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AddServiceRecordScreen(
          appliances: [appliance],
          initialApplianceId: appliance.id,
          record: record,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final intervalField = find.byKey(
      const ValueKey('serviceIntervalValueField'),
    );
    await tester.dragUntilVisible(
      intervalField,
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(intervalField);
    expect(field.controller?.text, '6');

    final unitField = find.byKey(const ValueKey('serviceIntervalUnitField'));
    expect(unitField, findsOneWidget);
    final dropdown = tester
        .widget<DropdownButtonFormField<ServiceIntervalUnit>>(unitField);
    expect(dropdown.initialValue, ServiceIntervalUnit.months);
    expect(find.text('Next service date'), findsOneWidget);
    expect(find.textContaining('12/08/2026'), findsOneWidget);
  });

  testWidgets(
    'service center falls back to All when Due soon has no matching records',
    (tester) async {
      final appliance = Appliance(
        id: 'service-center-ac',
        name: 'Bedroom AC',
        category: 'Air Conditioner',
        brand: 'Daikin',
        serviceRecords: [
          ServiceRecord(
            id: 'service-center-1',
            serviceDate: DateTime(2026, 8, 9),
            createdAt: DateTime(2026, 8, 9),
            ticketNumber: 'SR-100',
            problemDescription: 'Routine service',
            status: ServiceStatus.scheduled,
          ),
          ServiceRecord(
            id: 'service-center-2',
            serviceDate: DateTime(2026, 8, 10),
            createdAt: DateTime(2026, 8, 10),
            ticketNumber: 'SR-101',
            problemDescription: 'Filter cleaning',
            status: ServiceStatus.scheduled,
          ),
        ],
        createdAt: DateTime(2026, 1, 1),
      );
      final store = ApplianceStore(
        repository: MemoryApplianceRepository(initialAppliances: [appliance]),
      );
      await store.initialize();
      addTearDown(store.dispose);

      await tester.pumpWidget(
        AppScope(
          applianceStore: store,
          child: MaterialApp(
            home: ServiceCenterScreen(
              initialFilter: ServiceFilter.dueSoon,
              now: DateTime(2026, 8, 9),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final allChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'All'),
      );
      expect(allChip.selected, isTrue);
      expect(find.text('Open • SR-100'), findsOneWidget);
      expect(find.text('Scheduled • SR-101'), findsOneWidget);
    },
  );

  testWidgets('service center leaves visible spacing between record cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appliance = Appliance(
      id: 'service-spacing-ac',
      name: 'LG AC',
      category: 'Air Conditioner',
      brand: 'LG',
      serviceRecords: [
        ServiceRecord(
          id: 'spacing-1',
          serviceDate: DateTime(2026, 2, 12),
          createdAt: DateTime(2026, 2, 12),
          provider: 'LG Care',
          ticketNumber: 'SR-200',
          problemDescription: 'Deep cleaning and preventive maintenance',
          serviceIntervalValue: 6,
          nextServiceDate: DateTime(2026, 8, 12),
          status: ServiceStatus.completed,
        ),
        ServiceRecord(
          id: 'spacing-2',
          serviceDate: DateTime(2026, 3, 12),
          createdAt: DateTime(2026, 3, 12),
          provider: 'LG Care',
          ticketNumber: 'SR-201',
          problemDescription: 'Filter replacement and inspection',
          serviceIntervalValue: 6,
          nextServiceDate: DateTime(2026, 9, 12),
          status: ServiceStatus.completed,
        ),
      ],
      createdAt: DateTime(2026, 1, 1),
    );
    final store = ApplianceStore(
      repository: MemoryApplianceRepository(initialAppliances: [appliance]),
    );
    await store.initialize();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      AppScope(
        applianceStore: store,
        child: const MaterialApp(home: ServiceCenterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final first = find.byKey(const ValueKey('serviceRecord-spacing-2'));
    final second = find.byKey(const ValueKey('serviceRecord-spacing-1'));
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);

    final firstBottom = tester.getBottomLeft(first).dy;
    final secondTop = tester.getTopLeft(second).dy;
    expect(secondTop - firstBottom, greaterThanOrEqualTo(9));
  });

  testWidgets('service status filters are mutually exclusive', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appliance = Appliance(
      id: 'status-filter-appliance',
      name: 'Test appliance',
      category: 'Other',
      brand: 'Test',
      serviceRecords: [
        ServiceRecord(
          id: 'scheduled-record',
          serviceDate: DateTime(2026, 8, 20),
          createdAt: DateTime(2026, 8, 1),
          ticketNumber: 'SCHEDULED-1',
          status: ServiceStatus.scheduled,
        ),
        ServiceRecord(
          id: 'open-record',
          serviceDate: DateTime(2026, 8, 21),
          createdAt: DateTime(2026, 8, 1),
          ticketNumber: 'OPEN-1',
          status: ServiceStatus.open,
        ),
        ServiceRecord(
          id: 'progress-record',
          serviceDate: DateTime(2026, 8, 22),
          createdAt: DateTime(2026, 8, 1),
          ticketNumber: 'PROGRESS-1',
          status: ServiceStatus.inProgress,
        ),
      ],
      createdAt: DateTime(2026, 1, 1),
    );

    final store = ApplianceStore(
      repository: MemoryApplianceRepository(initialAppliances: [appliance]),
    );
    await store.initialize();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      AppScope(
        applianceStore: store,
        child: const MaterialApp(home: ServiceCenterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Scheduled'));
    await tester.pumpAndSettle();
    expect(find.text('Scheduled • SCHEDULED-1'), findsOneWidget);
    expect(find.text('Open • OPEN-1'), findsNothing);
    expect(find.text('Open • PROGRESS-1'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Open'));
    await tester.pumpAndSettle();
    expect(find.text('Scheduled • SCHEDULED-1'), findsNothing);
    expect(find.text('Open • OPEN-1'), findsOneWidget);
    expect(find.text('Open • PROGRESS-1'), findsOneWidget);
  });

  group('Scheduled service rollover', () {
    final referenceDate = DateTime(2026, 8, 9, 8, 30);

    test('future scheduled service remains Scheduled', () {
      final record = ServiceRecord(
        id: 'future',
        serviceDate: DateTime(2026, 8, 10),
        createdAt: DateTime(2026, 8, 1),
        status: ServiceStatus.scheduled,
      );

      expect(record.effectiveStatus(referenceDate), ServiceStatus.scheduled);
    });

    test('scheduled service becomes Open on its service date', () {
      final record = ServiceRecord(
        id: 'today',
        serviceDate: DateTime(2026, 8, 9, 23, 59),
        createdAt: DateTime(2026, 8, 1),
        status: ServiceStatus.scheduled,
      );

      expect(record.effectiveStatus(referenceDate), ServiceStatus.open);
    });

    test('overdue scheduled service remains Open until resolved', () {
      final record = ServiceRecord(
        id: 'past',
        serviceDate: DateTime(2026, 8, 8),
        createdAt: DateTime(2026, 8, 1),
        status: ServiceStatus.scheduled,
      );

      expect(record.effectiveStatus(referenceDate), ServiceStatus.open);
    });

    test('Completed and Cancelled statuses are never auto-reopened', () {
      final completed = ServiceRecord(
        id: 'completed',
        serviceDate: DateTime(2026, 8, 9),
        createdAt: DateTime(2026, 8, 1),
        status: ServiceStatus.completed,
      );
      final cancelled = ServiceRecord(
        id: 'cancelled',
        serviceDate: DateTime(2026, 8, 9),
        createdAt: DateTime(2026, 8, 1),
        status: ServiceStatus.cancelled,
      );

      expect(completed.effectiveStatus(referenceDate), ServiceStatus.completed);
      expect(cancelled.effectiveStatus(referenceDate), ServiceStatus.cancelled);
    });
  });

  testWidgets('service center moves due Scheduled records into Open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appliance = Appliance(
      id: 'rollover-appliance',
      name: 'Bedroom Geyser',
      category: 'Water Heater',
      brand: 'AO Smith',
      serviceRecords: [
        ServiceRecord(
          id: 'today-service',
          serviceDate: DateTime(2026, 8, 9),
          createdAt: DateTime(2026, 8, 1),
          ticketNumber: 'TODAY-1',
          status: ServiceStatus.scheduled,
        ),
        ServiceRecord(
          id: 'future-service',
          serviceDate: DateTime(2026, 8, 10),
          createdAt: DateTime(2026, 8, 1),
          ticketNumber: 'FUTURE-1',
          status: ServiceStatus.scheduled,
        ),
      ],
      createdAt: DateTime(2026, 1, 1),
    );

    final store = ApplianceStore(
      repository: MemoryApplianceRepository(initialAppliances: [appliance]),
    );
    await store.initialize();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      AppScope(
        applianceStore: store,
        child: MaterialApp(
          home: ServiceCenterScreen(now: DateTime(2026, 8, 9, 16)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Open'));
    await tester.pumpAndSettle();

    expect(find.text('Open • TODAY-1'), findsOneWidget);
    expect(find.text('Scheduled • FUTURE-1'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Scheduled'));
    await tester.pumpAndSettle();

    expect(find.text('Open • TODAY-1'), findsNothing);
    expect(find.text('Scheduled • FUTURE-1'), findsOneWidget);
  });

  testWidgets(
    'All service records are ordered Open, Scheduled, Due soon, Completed, Cancelled',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appliance = Appliance(
        id: 'priority-appliance',
        name: 'Priority appliance',
        category: 'Other',
        brand: 'Test',
        serviceRecords: [
          ServiceRecord(
            id: 'cancelled',
            serviceDate: DateTime(2026, 8, 1),
            createdAt: DateTime(2026, 7, 1),
            ticketNumber: 'CANCELLED',
            status: ServiceStatus.cancelled,
          ),
          ServiceRecord(
            id: 'completed',
            serviceDate: DateTime(2026, 8, 2),
            createdAt: DateTime(2026, 7, 1),
            ticketNumber: 'COMPLETED',
            status: ServiceStatus.completed,
          ),
          ServiceRecord(
            id: 'due-soon',
            serviceDate: DateTime(2026, 2, 12),
            createdAt: DateTime(2026, 2, 1),
            ticketNumber: 'DUE-SOON',
            status: ServiceStatus.completed,
            serviceIntervalValue: 6,
            serviceIntervalUnit: ServiceIntervalUnit.months,
            nextServiceDate: DateTime(2026, 8, 12),
          ),
          ServiceRecord(
            id: 'scheduled',
            serviceDate: DateTime(2026, 8, 15),
            createdAt: DateTime(2026, 8, 1),
            ticketNumber: 'SCHEDULED',
            status: ServiceStatus.scheduled,
          ),
          ServiceRecord(
            id: 'open',
            serviceDate: DateTime(2026, 8, 9),
            createdAt: DateTime(2026, 8, 1),
            ticketNumber: 'OPEN',
            status: ServiceStatus.open,
          ),
        ],
        createdAt: DateTime(2026, 1, 1),
      );

      final store = ApplianceStore(
        repository: MemoryApplianceRepository(initialAppliances: [appliance]),
      );
      await store.initialize();
      addTearDown(store.dispose);

      await tester.pumpWidget(
        AppScope(
          applianceStore: store,
          child: MaterialApp(
            home: ServiceCenterScreen(now: DateTime(2026, 8, 9)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final openY = tester.getTopLeft(find.text('Open • OPEN')).dy;
      final scheduledY = tester
          .getTopLeft(find.text('Scheduled • SCHEDULED'))
          .dy;
      final dueSoonY = tester.getTopLeft(find.text('Completed • DUE-SOON')).dy;
      final completedY = tester
          .getTopLeft(find.text('Completed • COMPLETED'))
          .dy;
      final cancelledY = tester
          .getTopLeft(find.text('Cancelled • CANCELLED'))
          .dy;

      expect(openY, lessThan(scheduledY));
      expect(scheduledY, lessThan(dueSoonY));
      expect(dueSoonY, lessThan(completedY));
      expect(completedY, lessThan(cancelledY));
    },
  );
}
