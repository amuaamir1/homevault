import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/service_record.dart';
import 'package:homevault/screens/service/add_service_record_screen.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/services/homevault_report_service.dart';
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
}
