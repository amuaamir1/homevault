import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/service_record.dart';
import 'package:homevault/services/homevault_export_service.dart';

void main() {
  final createdAt = DateTime(2026, 8, 24);

  Appliance appliance() => Appliance(
    id: 'ac-1',
    name: 'Kitchen AC / Main',
    category: 'Air Conditioner',
    brand: 'Daikin',
    modelNumber: 'FTKF50',
    serialNumber: 'SERIAL-001',
    purchaseDate: DateTime(2026, 1, 10),
    warrantyExpiryDate: DateTime(2028, 1, 10),
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
