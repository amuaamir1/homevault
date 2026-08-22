import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/backup_models.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/services/homevault_backup_service.dart';

void main() {
  test(
    'backup round trip restores appliance data and document bytes',
    () async {
      final sourceDirectory = await Directory.systemTemp.createTemp(
        'homevault_backup_source_',
      );
      final restoreDirectory = await Directory.systemTemp.createTemp(
        'homevault_backup_restore_',
      );

      try {
        final sourceDocument = File('${sourceDirectory.path}/invoice.pdf');
        await sourceDocument.writeAsBytes([1, 2, 3, 4, 5]);

        final appliance = Appliance(
          id: 'appliance-1',
          name: 'Kitchen fridge',
          category: 'Kitchen Appliance',
          brand: 'Samsung',
          serialNumber: 'SERIAL-001',
          invoiceDocument: StoredDocument(
            id: 'invoice-1',
            type: DocumentType.invoice,
            title: 'Purchase invoice',
            fileName: 'invoice.pdf',
            localPath: sourceDocument.path,
            sizeBytes: 5,
            attachedAt: DateTime(2026, 8, 2),
          ),
          createdAt: DateTime(2026, 8, 2),
        );

        final service = HomeVaultBackupService(
          documentsDirectoryProvider: () async => restoreDirectory,
        );
        final archive = await service.buildBackup([appliance]);
        final selection = service.inspectBackupBytes(
          archive.bytes,
          fileName: 'test-backup.zip',
        );
        final restored = await service.prepareRestore(
          selection: selection,
          existingAppliances: const [],
          mode: RestoreMode.replace,
        );

        expect(selection.preview.applianceCount, 1);
        expect(selection.preview.documentCount, 1);
        expect(restored.importedAppliances, 1);
        expect(restored.restoredDocuments, 1);
        expect(restored.missingDocuments, 0);
        expect(restored.appliances.single.name, 'Kitchen fridge');
        expect(
          restored.appliances.single.invoiceDocument?.displayTitle,
          'Purchase invoice',
        );

        final restoredPath =
            restored.appliances.single.invoiceDocument!.localPath;
        expect(await File(restoredPath).readAsBytes(), [1, 2, 3, 4, 5]);
      } finally {
        await sourceDirectory.delete(recursive: true);
        await restoreDirectory.delete(recursive: true);
      }
    },
  );

  test('merge restore skips an existing appliance ID', () async {
    final directory = await Directory.systemTemp.createTemp(
      'homevault_backup_duplicate_',
    );

    try {
      final appliance = Appliance(
        id: 'same-id',
        name: 'Existing AC',
        category: 'Air Conditioner',
        brand: 'Daikin',
        createdAt: DateTime(2026, 8, 2),
      );
      final service = HomeVaultBackupService(
        documentsDirectoryProvider: () async => directory,
      );
      final archive = await service.buildBackup([appliance]);
      final selection = service.inspectBackupBytes(
        archive.bytes,
        fileName: 'duplicate.zip',
      );
      final restored = await service.prepareRestore(
        selection: selection,
        existingAppliances: [appliance],
        mode: RestoreMode.merge,
      );

      expect(restored.appliances, isEmpty);
      expect(restored.importedAppliances, 0);
      expect(restored.skippedDuplicates, 1);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('replace restore skips duplicate serials inside one backup', () async {
    final directory = await Directory.systemTemp.createTemp(
      'homevault_backup_internal_duplicate_',
    );

    try {
      final first = Appliance(
        id: 'first-id',
        name: 'First fridge',
        category: 'Kitchen Appliance',
        brand: 'Samsung',
        serialNumber: 'SERIAL-1',
        createdAt: DateTime(2026, 8, 2),
      );
      final duplicate = Appliance(
        id: 'second-id',
        name: 'Duplicate fridge',
        category: 'Kitchen Appliance',
        brand: 'Samsung',
        serialNumber: 'serial-1',
        createdAt: DateTime(2026, 8, 2),
      );
      final service = HomeVaultBackupService(
        documentsDirectoryProvider: () async => directory,
      );
      final archive = await service.buildBackup([first, duplicate]);
      final selection = service.inspectBackupBytes(
        archive.bytes,
        fileName: 'internal-duplicate.zip',
      );
      final restored = await service.prepareRestore(
        selection: selection,
        existingAppliances: const [],
        mode: RestoreMode.replace,
      );

      expect(restored.importedAppliances, 1);
      expect(restored.skippedDuplicates, 1);
      expect(restored.appliances.single.id, 'first-id');
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('account-tagged backup rejects a different signed-in user', () async {
    final directory = await Directory.systemTemp.createTemp(
      'homevault_backup_owner_',
    );

    try {
      final appliance = Appliance(
        id: 'owned-appliance',
        name: 'Owned refrigerator',
        category: 'Kitchen Appliance',
        brand: 'Samsung',
        createdAt: DateTime(2026, 8, 2),
      );
      final service = HomeVaultBackupService(
        documentsDirectoryProvider: () async => directory,
      );
      final archive = await service.buildBackup([
        appliance,
      ], ownerUid: 'firebase-user-a');
      final selection = service.inspectBackupBytes(
        archive.bytes,
        fileName: 'owned-backup.zip',
      );

      expect(selection.preview.ownerFingerprint, isNotNull);
      await expectLater(
        service.prepareRestore(
          selection: selection,
          existingAppliances: const [],
          mode: RestoreMode.replace,
          currentOwnerUid: 'firebase-user-b',
        ),
        throwsA(isA<BackupFormatException>()),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('damaged data is rejected as an invalid backup', () {
    final service = HomeVaultBackupService();

    expect(
      () => service.inspectBackupBytes(
        Uint8List.fromList([1, 2, 3, 4]),
        fileName: 'damaged.zip',
      ),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('restored attachment clears stale cloud storage metadata', () async {
    final sourceDirectory = await Directory.systemTemp.createTemp(
      'homevault_backup_cloud_pointer_source_',
    );
    final restoreDirectory = await Directory.systemTemp.createTemp(
      'homevault_backup_cloud_pointer_restore_',
    );

    try {
      final sourceDocument = File('${sourceDirectory.path}/invoice.pdf');
      await sourceDocument.writeAsBytes([9, 8, 7]);

      final appliance = Appliance(
        id: 'cloud-pointer-appliance',
        name: 'Test appliance',
        category: 'Other',
        brand: 'Test',
        invoiceDocument: StoredDocument(
          id: 'cloud-pointer-document',
          type: DocumentType.invoice,
          fileName: 'invoice.pdf',
          localPath: sourceDocument.path,
          sizeBytes: 3,
          attachedAt: DateTime(2026, 8, 11),
          cloudStoragePath: 'users/old/appliances/a/documents/d/invoice.pdf',
          cloudContentType: 'application/pdf',
        ),
        createdAt: DateTime(2026, 8, 11),
      );

      final service = HomeVaultBackupService(
        documentsDirectoryProvider: () async => restoreDirectory,
      );
      final archive = await service.buildBackup([
        appliance,
      ], ownerUid: 'firebase-user-a');
      final selection = service.inspectBackupBytes(
        archive.bytes,
        fileName: 'cloud-pointer.zip',
      );
      final restored = await service.prepareRestore(
        selection: selection,
        existingAppliances: const [],
        mode: RestoreMode.replace,
        currentOwnerUid: 'firebase-user-a',
      );

      final document = restored.appliances.single.invoiceDocument!;
      expect(document.cloudStoragePath, isEmpty);
      expect(document.cloudContentType, isEmpty);
      expect(document.isAvailableOnDevice, isTrue);
      expect(document.needsCloudUpload, isTrue);
    } finally {
      await sourceDirectory.delete(recursive: true);
      await restoreDirectory.delete(recursive: true);
    }
  });
}
