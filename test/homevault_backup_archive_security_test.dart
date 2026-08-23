import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/models/backup_models.dart';
import 'package:homevault/services/homevault_backup_service.dart';

void main() {
  group('HomeVault backup archive security', () {
    test('accepts a minimal valid HomeVault ZIP container', () {
      final bytes = _zipWith(<ArchiveFile>[
        ArchiveFile.bytes(
          'manifest.json',
          utf8.encode(
            jsonEncode(<String, dynamic>{
              'format': HomeVaultBackupService.backupFormat,
              'schemaVersion': HomeVaultBackupService.backupSchemaVersion,
              'createdAt': DateTime.utc(2026, 8, 23).toIso8601String(),
              'appVersion': HomeVaultBackupService.appVersion,
              'documentCount': 0,
              'missingDocuments': const <Object>[],
              'appliances': const <Object>[],
            }),
          ),
        ),
      ]);

      final selection = HomeVaultBackupService().inspectBackupBytes(
        bytes,
        fileName: 'HomeVault_Backup.zip',
      );

      expect(selection.preview.applianceCount, 0);
    });

    test('rejects a ZIP with an unexpected archive path', () {
      final bytes = _zipWith(<ArchiveFile>[
        ArchiveFile.bytes(
          'manifest.json',
          utf8.encode(
            jsonEncode(<String, dynamic>{
              'format': HomeVaultBackupService.backupFormat,
              'schemaVersion': HomeVaultBackupService.backupSchemaVersion,
              'createdAt': DateTime.utc(2026, 8, 23).toIso8601String(),
              'appVersion': HomeVaultBackupService.appVersion,
              'documentCount': 0,
              'missingDocuments': const <Object>[],
              'appliances': const <Object>[],
            }),
          ),
        ),
        ArchiveFile.bytes('unexpected/payload.bin', <int>[1, 2, 3]),
      ]);

      expect(
        () => HomeVaultBackupService().inspectBackupBytes(
          bytes,
          fileName: 'HomeVault_Backup.zip',
        ),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects an attachment whose bytes do not match the file name', () {
      const archivePath = 'documents/appliance-1/document_invoice.pdf';
      final document = StoredDocument(
        id: 'document-1',
        type: DocumentType.invoice,
        title: 'Invoice',
        fileName: 'invoice.pdf',
        localPath: archivePath,
        sizeBytes: 4,
        attachedAt: DateTime.utc(2026, 8, 23),
      );
      final appliance = Appliance(
        id: 'appliance-1',
        name: 'Test appliance',
        category: 'Other',
        brand: 'Test',
        createdAt: DateTime.utc(2026, 8, 23),
        invoiceDocument: document,
      );

      final bytes = _zipWith(<ArchiveFile>[
        ArchiveFile.bytes(
          'manifest.json',
          utf8.encode(
            jsonEncode(<String, dynamic>{
              'format': HomeVaultBackupService.backupFormat,
              'schemaVersion': HomeVaultBackupService.backupSchemaVersion,
              'createdAt': DateTime.utc(2026, 8, 23).toIso8601String(),
              'appVersion': HomeVaultBackupService.appVersion,
              'documentCount': 1,
              'missingDocuments': const <Object>[],
              'appliances': <Object>[appliance.toJson()],
            }),
          ),
        ),
        ArchiveFile.bytes(archivePath, <int>[0xff, 0xd8, 0xff, 0xe0]),
      ]);

      expect(
        () => HomeVaultBackupService().inspectBackupBytes(
          bytes,
          fileName: 'HomeVault_Backup.zip',
        ),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects a backup with a non-ZIP file name', () {
      expect(
        () => HomeVaultBackupService().inspectBackupBytes(
          Uint8List.fromList(<int>[0x50, 0x4b, 0x05, 0x06]),
          fileName: 'backup.txt',
        ),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });
}

Uint8List _zipWith(List<ArchiveFile> files) {
  final archive = Archive();
  for (final file in files) {
    archive.addFile(file);
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}
