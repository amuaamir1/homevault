import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/services/document_vault_service.dart';

StoredDocument _doc({
  required String id,
  required DocumentType type,
  required String title,
  required DateTime attachedAt,
  String fileName = 'file.pdf',
  String localPath = '/local/file.pdf',
  String cloudStoragePath = '',
  String reference = '',
  String notes = '',
}) {
  return StoredDocument(
    id: id,
    type: type,
    title: title,
    fileName: fileName,
    localPath: localPath,
    cloudStoragePath: cloudStoragePath,
    sizeBytes: 1024,
    attachedAt: attachedAt,
    reference: reference,
    notes: notes,
  );
}

void main() {
  const service = DocumentVaultService();

  final ac = Appliance(
    id: 'ac',
    name: 'Living room AC',
    category: 'Air Conditioner',
    brand: 'Daikin',
    modelNumber: 'FTKM50',
    serialNumber: 'AC-123',
    appliancePhotoDocument: _doc(
      id: 'photo',
      type: DocumentType.appliancePhoto,
      title: 'AC photo',
      attachedAt: DateTime(2026, 8, 1),
      fileName: 'photo.jpg',
    ),
    invoiceDocument: _doc(
      id: 'invoice',
      type: DocumentType.invoice,
      title: 'Purchase invoice',
      attachedAt: DateTime(2026, 8, 10),
      reference: 'INV-900',
    ),
    additionalDocuments: [
      _doc(
        id: 'manual',
        type: DocumentType.userManual,
        title: 'Installation guide',
        attachedAt: DateTime(2026, 8, 5),
        localPath: '',
        cloudStoragePath: 'users/u/appliances/ac/documents/manual.pdf',
        notes: 'Remote control setup',
      ),
    ],
    createdAt: DateTime(2026, 8, 1),
  );

  final washer = Appliance(
    id: 'washer',
    name: 'Washing machine',
    category: 'Washing Machine',
    brand: 'LG',
    additionalDocuments: [
      _doc(
        id: 'report',
        type: DocumentType.serviceReport,
        title: 'Motor service report',
        attachedAt: DateTime(2026, 8, 20),
        localPath: '',
        notes: 'Bearing replacement',
      ),
    ],
    createdAt: DateTime(2026, 8, 1),
  );

  test('vault excludes appliance photos and summarizes availability', () {
    final entries = service.entries([ac, washer]);
    final summary = service.summarize(entries);

    expect(entries.map((entry) => entry.document.id), isNot(contains('photo')));
    expect(summary.totalDocuments, 3);
    expect(summary.appliancesWithDocuments, 2);
    expect(summary.cloudOnlyDocuments, 1);
    expect(summary.unavailableDocuments, 1);
  });

  test('category, appliance, type, and availability filters combine', () {
    final entries = service.entries([ac, washer]);
    final filtered = service.filterAndSort(
      entries,
      const DocumentVaultFilter(
        applianceId: 'ac',
        category: DocumentVaultCategory.manualsAndInstallation,
        type: DocumentType.userManual,
        availability: DocumentVaultAvailability.cloudOnly,
      ),
    );

    expect(filtered, hasLength(1));
    expect(filtered.single.document.id, 'manual');
  });

  test('search covers appliance metadata and document notes', () {
    final entries = service.entries([ac, washer]);

    final modelMatch = service.filterAndSort(
      entries,
      const DocumentVaultFilter(query: 'FTKM50 invoice'),
    );
    expect(modelMatch.map((entry) => entry.document.id), ['invoice']);

    final notesMatch = service.filterAndSort(
      entries,
      const DocumentVaultFilter(query: 'bearing replacement'),
    );
    expect(notesMatch.map((entry) => entry.document.id), ['report']);
  });

  test('sort supports newest, oldest, title, appliance, and type', () {
    final entries = service.entries([ac, washer]);

    expect(
      service
          .filterAndSort(entries, const DocumentVaultFilter())
          .map((entry) => entry.document.id)
          .first,
      'report',
    );
    expect(
      service
          .filterAndSort(
            entries,
            const DocumentVaultFilter(sort: DocumentVaultSort.oldest),
          )
          .map((entry) => entry.document.id)
          .first,
      'manual',
    );
    expect(
      service
          .filterAndSort(
            entries,
            const DocumentVaultFilter(sort: DocumentVaultSort.title),
          )
          .map((entry) => entry.document.id)
          .first,
      'manual',
    );
    expect(
      service
          .filterAndSort(
            entries,
            const DocumentVaultFilter(sort: DocumentVaultSort.appliance),
          )
          .map((entry) => entry.appliance.id)
          .first,
      'ac',
    );
    expect(
      service
          .filterAndSort(
            entries,
            const DocumentVaultFilter(sort: DocumentVaultSort.type),
          )
          .map((entry) => entry.document.type)
          .first,
      DocumentType.invoice,
    );
  });
}
