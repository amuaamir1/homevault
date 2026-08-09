import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/services/cloud_document_storage_service.dart';
import 'package:homevault/services/document_storage_service.dart';
import 'package:homevault/state/appliance_store.dart';

class _FakeCloudDocumentStorage implements CloudDocumentStorage {
  String? ownerUid;
  final List<String> uploadedIds = [];
  final List<String> downloadedIds = [];
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
    downloadedIds.add(document.id);
    return document.copyWith(localPath: destinationPath);
  }

  @override
  Future<void> delete(StoredDocument document) async {
    deletedPaths.add(document.cloudStoragePath);
  }
}

class _FakeDocumentStorageService extends DocumentStorageService {
  @override
  Future<String> prepareDownloadDestination({
    required String applianceId,
    required StoredDocument document,
  }) async {
    return '/cache/$applianceId/${document.id}/${document.fileName}';
  }

  @override
  Future<void> deleteStoredDocument(StoredDocument document) async {}
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

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Timed out waiting for the background document synchronization.');
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
      documentStorageService: _FakeDocumentStorageService(),
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

  test('cloud-only document is cached automatically after sign-in', () async {
    const cloudPath =
        'users/user-1/appliances/appliance-1/documents/invoice-1/file.pdf';
    final repository = MemoryApplianceRepository(
      initialAppliances: [
        _appliance(_document(localPath: '', cloudPath: cloudPath)),
      ],
    );
    final cloudStorage = _FakeCloudDocumentStorage();
    final store = ApplianceStore(
      repository: repository,
      cloudDocumentStorage: cloudStorage,
      documentStorageService: _FakeDocumentStorageService(),
    );

    await store.bindOwner('user-1');
    await _waitUntil(
      () => store.appliances.single.invoiceDocument!.isAvailableOnDevice,
    );

    final cached = store.appliances.single.invoiceDocument!;
    expect(cloudStorage.downloadedIds, ['invoice-1']);
    expect(cached.localPath, '/cache/appliance-1/invoice-1/invoice.pdf');
    expect(cached.isAvailableInCloud, isTrue);

    final persisted = await repository.loadAppliances();
    expect(
      persisted.single.invoiceDocument!.localPath,
      '/cache/appliance-1/invoice-1/invoice.pdf',
    );

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
      documentStorageService: _FakeDocumentStorageService(),
    );

    await store.bindOwner('user-1');
    await store.removeDocument('appliance-1', 'invoice-1');

    expect(store.appliances.single.invoiceDocument, isNull);
    expect(cloudStorage.deletedPaths, contains(cloudPath));

    store.dispose();
  });
}
