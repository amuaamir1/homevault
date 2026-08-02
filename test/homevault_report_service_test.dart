import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/service_record.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/services/homevault_report_service.dart';

void main() {
  test('reports calculate portfolio totals and upcoming actions', () {
    final referenceDate = DateTime(2026, 8, 2);
    final appliances = [
      Appliance(
        id: 'ac-1',
        name: 'Family room AC',
        category: 'Air Conditioner',
        brand: 'Daikin',
        warrantyExpiryDate: DateTime(2026, 8, 22),
        supportProvider: 'Daikin Care',
        additionalDocuments: [
          StoredDocument(
            id: 'invoice-1',
            type: DocumentType.invoice,
            title: 'AC invoice',
            fileName: 'invoice.pdf',
            localPath: '/documents/invoice.pdf',
            sizeBytes: 1000,
            attachedAt: referenceDate,
          ),
        ],
        serviceRecords: [
          ServiceRecord(
            id: 'service-1',
            serviceDate: referenceDate,
            createdAt: referenceDate,
            provider: 'Cool Care',
            serviceCharge: 1500,
            nextServiceDate: DateTime(2026, 8, 12),
            status: ServiceStatus.open,
          ),
        ],
        createdAt: referenceDate,
      ),
      Appliance(
        id: 'geyser-1',
        name: 'Bathroom geyser',
        category: 'Geyser / Water Heater',
        brand: 'Bajaj',
        createdAt: referenceDate,
      ),
    ];

    final report = const HomeVaultReportService().build(
      appliances,
      now: referenceDate,
    );

    expect(report.totalAppliances, 2);
    expect(report.totalDocuments, 1);
    expect(report.totalServiceRecords, 1);
    expect(report.totalServiceCost, 1500);
    expect(report.activeServiceRecords, 1);
    expect(report.appliancesWithDocuments, 1);
    expect(report.appliancesWithSupport, 1);
    expect(report.appliancesWithWarrantyDate, 1);
    expect(report.appliancesWithServiceHistory, 1);
    expect(report.warrantyCount(WarrantyStatus.expiringSoon), 1);
    expect(report.warrantyCount(WarrantyStatus.notProvided), 1);
    expect(report.upcomingWarranties.single.applianceId, 'ac-1');
    expect(report.upcomingServices.single.applianceId, 'ac-1');
    expect(report.topMaintenanceCosts.single.cost, 1500);
    expect(report.categoryBreakdown.length, 2);
  });

  test('empty portfolio produces safe zero-valued reports', () {
    final report = const HomeVaultReportService().build(
      const [],
      now: DateTime(2026, 8, 2),
    );

    expect(report.totalAppliances, 0);
    expect(report.totalDocuments, 0);
    expect(report.totalServiceCost, 0);
    expect(report.completionRate(0), 0);
    expect(report.upcomingServices, isEmpty);
    expect(report.upcomingWarranties, isEmpty);
  });
}
