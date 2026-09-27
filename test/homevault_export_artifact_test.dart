import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/service_record.dart';
import 'package:homevault/services/homevault_export_service.dart';

void main() {
  final createdAt = DateTime(2026, 8, 24);

  Appliance appliance({
    bool warrantyReminderEnabled = false,
    int warrantyReminderDaysBefore = 30,
  }) => Appliance(
    id: 'ac-1',
    name: 'Kitchen AC / Main',
    category: 'Air Conditioner',
    brand: 'Daikin',
    modelNumber: 'FTKF50',
    serialNumber: 'SERIAL-001',
    purchaseDate: DateTime(2026, 1, 10),
    warrantyExpiryDate: DateTime(2028, 1, 10),
    warrantyReminderEnabled: warrantyReminderEnabled,
    warrantyReminderDaysBefore: warrantyReminderDaysBefore,
    serviceRecords: [
      ServiceRecord(
        id: 'service-1',
        serviceDate: DateTime(2026, 7, 1),
        createdAt: createdAt,
        provider: 'Daikin Care',
        serviceCharge: 1250,
      ),
    ],
    createdAt: createdAt,
  );

  test(
    'CSV export artifacts are share-ready without invoking a file picker',
    () {
      const service = HomeVaultExportService();

      final inventory = service.createApplianceInventoryArtifact([appliance()]);
      final warranty = service.createWarrantyReportArtifact([appliance()]);
      final serviceCost = service.createServiceCostReportArtifact([
        appliance(),
      ]);

      for (final artifact in [inventory, warranty, serviceCost]) {
        expect(artifact.mimeType, 'text/csv');
        expect(artifact.extension, 'csv');
        expect(artifact.fileName, startsWith('HomeVault_'));
        expect(artifact.fileName, endsWith('.csv'));
        expect(artifact.bytes, isNotEmpty);
      }

      final inventoryText = utf8.decode(inventory.bytes);
      expect(inventoryText, contains('Appliance name'));
      expect(inventoryText, contains('Kitchen AC / Main'));
      expect(inventoryText, contains('SERIAL-001'));

      final warrantyText = utf8.decode(warranty.bytes);
      expect(warrantyText, contains('Warranty status'));
      expect(warrantyText, contains('Daikin'));

      final serviceText = utf8.decode(serviceCost.bytes);
      expect(serviceText, contains('Service charge'));
      expect(serviceText, contains('1250.00'));
    },
  );

  test(
    'warranty report distinguishes the active fixed policy from legacy days',
    () {
      const service = HomeVaultExportService();
      final artifact = service.createWarrantyReportArtifact([
        appliance(
          warrantyReminderEnabled: true,
          warrantyReminderDaysBefore: 90,
        ),
      ]);
      final lines = utf8.decode(artifact.bytes).split('\r\n');
      final headers = _simpleCsvColumns(lines[0]);
      final values = _simpleCsvColumns(lines[1]);

      final activePolicyIndex = headers.indexOf(
        'Active warranty reminder policy',
      );
      final legacyDaysIndex = headers.indexOf(
        'Legacy reminder days before (inactive)',
      );

      expect(activePolicyIndex, greaterThanOrEqualTo(0));
      expect(legacyDaysIndex, greaterThanOrEqualTo(0));
      expect(
        values[activePolicyIndex],
        'Fixed 30-day and 7-day reminders before warranty expiry',
      );
      expect(values[activePolicyIndex], isNot(contains('90')));
      expect(values[legacyDaysIndex], '90');
      expect(headers[legacyDaysIndex], contains('inactive'));
    },
  );

  test('PDF artifact has a safe filename and valid PDF signature', () async {
    const service = HomeVaultExportService();

    final artifact = await service.createAppliancePdfArtifact(appliance());

    expect(artifact.mimeType, 'application/pdf');
    expect(artifact.extension, 'pdf');
    expect(artifact.fileName, startsWith('HomeVault_Kitchen_AC___Main_'));
    expect(artifact.fileName, endsWith('.pdf'));
    expect(artifact.fileName, isNot(contains('/')));
    expect(artifact.fileName, isNot(contains(r'\')));
    expect(artifact.bytes.length, greaterThan(100));
    expect(ascii.decode(artifact.bytes.take(4).toList()), '%PDF');
  });
}

List<String> _simpleCsvColumns(String row) {
  final withoutBom = row.replaceFirst('\uFEFF', '');
  return withoutBom
      .substring(1, withoutBom.length - 1)
      .split('","')
      .map((value) => value.replaceAll('""', '"'))
      .toList(growable: false);
}
