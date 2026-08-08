import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/services/cloud_document_storage_service.dart';
import 'package:homevault/state/appliance_store.dart';

class _FakeCloudDocumentStorage implements CloudDocumentStorage {
  String? ownerUid;
  final List<String> uploadedIds = [];
  final List<String> deletedPaths = [];

  @override
  bool get isAvailable => true;

  @override
  Future<void> bindOwner(String? uid) async {
    ownerUid = uid;
  }

  @override
  Future<StoredDocument> upload({
    required String applianceId,
    required StoredDocument document,
  }) async {
    uploadedIds.add(document.id);
    return document.copyWith(
      cloudStoragePath:
          'users/$ownerUid/appliances/$applianceId/documents/${document.id}/file.pdf',
      cloudContentType: 'application/pdf',
    );
  }

  @override
  Future<StoredDocument> download({
    required StoredDocument document,
    required String destinationPath,
  }) async {
    return document.copyWith(localPath: destinationPath);
  }

  @override
  Future<void> delete(StoredDocument document) async {
    deletedPaths.add(document.cloudStoragePath);
  }
}

StoredDocument _document({
  String id = 'invoice-1',
  String localPath = '/local/invoice.pdf',
  String cloudPath = '',
}) {
  return StoredDocument(
    id: id,
    type: DocumentType.invoice,
    title: 'Invoice',
    fileName: 'invoice.pdf',
    localPath: localPath,
    sizeBytes: 1024,
    attachedAt: DateTime(2026, 8, 8),
    cloudStoragePath: cloudPath,
    cloudContentType: cloudPath.isEmpty ? '' : 'application/pdf',
  );
}

Appliance _appliance(StoredDocument? document) {
  return Appliance(
    id: 'appliance-1',
    name: 'Air conditioner',
    category: 'Air Conditioner',
    brand: 'LG',
    createdAt: DateTime(2026, 8, 8),
    invoiceDocument: document,
  );
}

void main() {
  test('cloud document metadata survives JSON round trip', () {
    final original = _document(
      cloudPath:
          'users/user-1/appliances/appliance-1/documents/invoice-1/file.pdf',
    );

    final restored = StoredDocument.fromJson(original.toJson());

    expect(restored.localPath, '/local/invoice.pdf');
    expect(restored.isAvailableOnDevice, isTrue);
    expect(restored.isAvailableInCloud, isTrue);
    expect(restored.cloudContentType, 'application/pdf');

    final cloudMetadata = restored.toCloudMetadataJson();
    expect(cloudMetadata['localPath'], '');
    expect(
      cloudMetadata['cloudStoragePath'],
      'users/user-1/appliances/appliance-1/documents/invoice-1/file.pdf',
    );
  });

  test('existing local-only document is migrated to cloud metadata', () async {
    final repository = MemoryApplianceRepository(
      initialAppliances: [_appliance(_document())],
    );
    final cloudStorage = _FakeCloudDocumentStorage();
    final store = ApplianceStore(
      repository: repository,
      cloudDocumentStorage: cloudStorage,
    );

    await store.bindOwner('user-1');
    await store.retryCloudDocumentSync();

    final migrated = store.appliances.single.invoiceDocument!;
    expect(cloudStorage.ownerUid, 'user-1');
    expect(cloudStorage.uploadedIds, contains('invoice-1'));
    expect(migrated.isAvailableOnDevice, isTrue);
    expect(migrated.isAvailableInCloud, isTrue);

    final persisted = await repository.loadAppliances();
    expect(persisted.single.invoiceDocument!.isAvailableInCloud, isTrue);

    store.dispose();
  });

  test('removing document cleans its previous cloud object', () async {
    final cloudPath =
        'users/user-1/appliances/appliance-1/documents/invoice-1/file.pdf';
    final repository = MemoryApplianceRepository(
      initialAppliances: [_appliance(_document(cloudPath: cloudPath))],
    );
    final cloudStorage = _FakeCloudDocumentStorage();
    final store = ApplianceStore(
      repository: repository,
      cloudDocumentStorage: cloudStorage,
    );

    await store.bindOwner('user-1');
    await store.removeDocument('appliance-1', 'invoice-1');

    expect(store.appliances.single.invoiceDocument, isNull);
    expect(cloudStorage.deletedPaths, contains(cloudPath));

    store.dispose();
  });
}
