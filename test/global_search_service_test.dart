import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/global_search_result.dart';
import 'package:homevault/models/service_record.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/services/global_search_service.dart';

void main() {
  final appliance = Appliance(
    id: 'ac-1',
    name: 'Family room AC',
    category: 'Air Conditioner',
    brand: 'Daikin',
    modelNumber: 'FTKM50',
    serialNumber: 'SN-100',
    supportProvider: 'Daikin Care',
    supportEmail: 'care@example.com',
    warrantyProvider: 'Daikin Care',
    warrantyReference: 'WAR-100',
    warrantyClaimNumber: 'CLM-50',
    warrantyExpiryDate: DateTime(2027, 8, 1),
    additionalDocuments: [
      StoredDocument(
        id: 'manual-1',
        type: DocumentType.userManual,
        title: 'Cooling guide',
        reference: 'MAN-10',
        fileName: 'manual.pdf',
        localPath: '/documents/manual.pdf',
        sizeBytes: 1024,
        attachedAt: DateTime(2026, 8, 1),
      ),
    ],
    serviceRecords: [
      ServiceRecord(
        id: 'service-1',
        serviceDate: DateTime(2026, 8, 2),
        createdAt: DateTime(2026, 8, 2),
        provider: 'Cool Care',
        ticketNumber: 'SR-200',
        problemDescription: 'Cooling reduced',
        status: ServiceStatus.completed,
      ),
    ],
    createdAt: DateTime(2026, 8, 1),
  );

  test('global search finds records across all HomeVault sections', () {
    const service = GlobalSearchService();

    expect(
      service.search(appliances: [appliance], query: 'FTKM50').single.type,
      GlobalSearchResultType.appliance,
    );
    expect(
      service.search(appliances: [appliance], query: 'MAN-10').single.type,
      GlobalSearchResultType.document,
    );
    expect(
      service
          .search(appliances: [appliance], query: 'care@example.com')
          .single
          .type,
      GlobalSearchResultType.support,
    );
    expect(
      service.search(appliances: [appliance], query: 'CLM-50').single.type,
      GlobalSearchResultType.warranty,
    );
    expect(
      service.search(appliances: [appliance], query: 'SR-200').single.type,
      GlobalSearchResultType.service,
    );
  });

  test('global search filters limit result types', () {
    const service = GlobalSearchService();

    final results = service.search(
      appliances: [appliance],
      query: 'Daikin',
      filter: GlobalSearchFilter.support,
    );

    expect(results, isNotEmpty);
    expect(
      results.every((result) => result.type == GlobalSearchResultType.support),
      isTrue,
    );
  });

  test('global search requires every query token to match', () {
    const service = GlobalSearchService();

    final matches = service.search(
      appliances: [appliance],
      query: 'family Daikin',
    );
    final misses = service.search(
      appliances: [appliance],
      query: 'family Samsung',
    );

    expect(matches, isNotEmpty);
    expect(misses, isEmpty);
  });
}
