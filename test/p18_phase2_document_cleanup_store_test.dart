import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/services/document_storage_service.dart';
import 'package:homevault/services/local_document_cache_policy.dart';
import 'package:homevault/state/appliance_store.dart';

class _TestDocumentStorageService extends DocumentStorageService {
  @override
  Future<void> deleteStoredDocument(StoredDocument document) async {
    final file = File(document.localPath);
    if (await file.exists()) await file.delete();
  }
}

void main() {
  test('cleanup releases only cloud-backed local document copies', () async {
    final root = await Directory.systemTemp.createTemp('homevault-p18-store-');
    addTearDown(() => root.delete(recursive: true));

    final recoverableFile = File(
      '${root.path}${Platform.pathSeparator}cloud.pdf',
    );
    final localOnlyFile = File(
      '${root.path}${Platform.pathSeparator}local.pdf',
    );
    await recoverableFile.writeAsBytes(List<int>.filled(1200, 1));
    await localOnlyFile.writeAsBytes(List<int>.filled(700, 2));

    final recoverable = StoredDocument(
      id: 'recoverable',
      fileName: 'cloud.pdf',
      localPath: recoverableFile.path,
      sizeBytes: 1200,
      attachedAt: DateTime(2026, 8, 23),
      cloudStoragePath: 'users/owner-a/documents/cloud.pdf',
    );
    final localOnly = StoredDocument(
      id: 'local-only',
      fileName: 'local.pdf',
      localPath: localOnlyFile.path,
      sizeBytes: 700,
      attachedAt: DateTime(2026, 8, 23),
    );

    final appliance = Appliance(
      id: 'appliance-1',
      name: 'Test appliance',
      category: 'Other',
      brand: 'HomeVault',
      createdAt: DateTime(2026, 8, 23),
      additionalDocuments: [recoverable, localOnly],
    );
    final policy = MemoryLocalDocumentCachePolicy();
    final store = ApplianceStore(
      repository: MemoryApplianceRepository(initialAppliances: [appliance]),
      documentStorageService: _TestDocumentStorageService(),
      localDocumentCachePolicy: policy,
    );
    addTearDown(store.dispose);

    await store.bindOwner('owner-a');
    final result = await store.clearDownloadedDocumentCopies();

    expect(result.itemCount, 1);
    expect(result.bytesFreed, 1200);
    expect(result.failedItems, 0);
    expect(await recoverableFile.exists(), isFalse);
    expect(await localOnlyFile.exists(), isTrue);

    final updated = store.applianceById('appliance-1')!;
    final cloudDocument = updated.allAttachments.firstWhere(
      (document) => document.id == 'recoverable',
    );
    final preservedLocalOnly = updated.allAttachments.firstWhere(
      (document) => document.id == 'local-only',
    );

    expect(cloudDocument.localPath, isEmpty);
    expect(cloudDocument.isAvailableInCloud, isTrue);
    expect(preservedLocalOnly.localPath, localOnlyFile.path);
    expect(
      await policy.evictedCloudPaths(),
      contains('users/owner-a/documents/cloud.pdf'),
    );

    // The intentionally released cloud copy is not pending re-download, but
    // the protected local-only file still needs a cloud upload. Therefore the
    // store must continue reporting pending cloud document work.
    expect(preservedLocalOnly.needsCloudUpload, isTrue);
    expect(store.hasPendingCloudDocumentWork, isTrue);
  });

  test(
    'released cloud-backed copy is not reported as pending document work',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'homevault-p18-store-cloud-only-',
      );
      addTearDown(() => root.delete(recursive: true));

      final recoverableFile = File(
        '${root.path}${Platform.pathSeparator}cloud-only.pdf',
      );
      await recoverableFile.writeAsBytes(List<int>.filled(900, 3));

      final recoverable = StoredDocument(
        id: 'recoverable-only',
        fileName: 'cloud-only.pdf',
        localPath: recoverableFile.path,
        sizeBytes: 900,
        attachedAt: DateTime(2026, 8, 23),
        cloudStoragePath: 'users/owner-a/documents/cloud-only.pdf',
      );

      final appliance = Appliance(
        id: 'appliance-cloud-only',
        name: 'Cloud-only cleanup test',
        category: 'Other',
        brand: 'HomeVault',
        createdAt: DateTime(2026, 8, 23),
        additionalDocuments: [recoverable],
      );

      final policy = MemoryLocalDocumentCachePolicy();
      final store = ApplianceStore(
        repository: MemoryApplianceRepository(initialAppliances: [appliance]),
        documentStorageService: _TestDocumentStorageService(),
        localDocumentCachePolicy: policy,
      );
      addTearDown(store.dispose);

      await store.bindOwner('owner-a');
      expect(store.hasPendingCloudDocumentWork, isFalse);

      final result = await store.clearDownloadedDocumentCopies();

      expect(result.itemCount, 1);
      expect(await recoverableFile.exists(), isFalse);

      final updated = store.applianceById('appliance-cloud-only')!;
      final released = updated.allAttachments.single;

      expect(released.localPath, isEmpty);
      expect(released.isAvailableInCloud, isTrue);
      expect(
        await policy.evictedCloudPaths(),
        contains('users/owner-a/documents/cloud-only.pdf'),
      );

      // The release is intentional, so background sync must not immediately
      // classify it as work that needs to download again.
      expect(store.hasPendingCloudDocumentWork, isFalse);
    },
  );
}
