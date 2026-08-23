import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/security/security_scope_key.dart';
import 'package:homevault/services/local_data_management_service.dart';
import 'package:path/path.dart' as path;

void main() {
  test('storage summary separates recoverable and local-only files', () async {
    final root = await Directory.systemTemp.createTemp('homevault-p18-phase2-');
    addTearDown(() => root.delete(recursive: true));

    final cloudFile = File(path.join(root.path, 'cloud.pdf'));
    final localFile = File(path.join(root.path, 'local.pdf'));
    await cloudFile.writeAsBytes(List<int>.filled(1500, 1));
    await localFile.writeAsBytes(List<int>.filled(800, 2));

    final service = LocalDataManagementService(
      documentsDirectoryProvider: () async => root,
    );

    const ownerUid = 'phase2-owner';
    final safetyDirectory = Directory(
      path.join(
        root.path,
        'homevault',
        'safety_backups',
        securityScopeKey(ownerUid),
      ),
    );
    await safetyDirectory.create(recursive: true);
    await File(
      path.join(safetyDirectory.path, 'Safety_1.zip'),
    ).writeAsBytes(List<int>.filled(500, 3));

    final documents = [
      StoredDocument(
        id: 'cloud',
        fileName: 'cloud.pdf',
        localPath: cloudFile.path,
        sizeBytes: 1500,
        attachedAt: DateTime(2026, 8, 23),
        cloudStoragePath: 'users/phase2-owner/documents/cloud.pdf',
      ),
      StoredDocument(
        id: 'local',
        fileName: 'local.pdf',
        localPath: localFile.path,
        sizeBytes: 800,
        attachedAt: DateTime(2026, 8, 23),
      ),
    ];

    final summary = await service.summarize(
      documents: documents,
      ownerUid: ownerUid,
    );

    expect(summary.cloudBackedDocumentCount, 1);
    expect(summary.cloudBackedDocumentBytes, 1500);
    expect(summary.localOnlyDocumentCount, 1);
    expect(summary.localOnlyDocumentBytes, 800);
    expect(summary.safetyBackupCount, 1);
    expect(summary.safetyBackupBytes, 500);
    expect(summary.totalManagedBytes, 2800);
  });

  test(
    'clearing safety backups stays inside the signed-in owner scope',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'homevault-p18-safety-',
      );
      addTearDown(() => root.delete(recursive: true));

      const ownerA = 'owner-a';
      const ownerB = 'owner-b';
      final ownerADirectory = Directory(
        path.join(
          root.path,
          'homevault',
          'safety_backups',
          securityScopeKey(ownerA),
        ),
      );
      final ownerBDirectory = Directory(
        path.join(
          root.path,
          'homevault',
          'safety_backups',
          securityScopeKey(ownerB),
        ),
      );
      await ownerADirectory.create(recursive: true);
      await ownerBDirectory.create(recursive: true);
      await File(
        path.join(ownerADirectory.path, 'Safety_A.zip'),
      ).writeAsBytes(List<int>.filled(256, 1));
      final ownerBFile = File(path.join(ownerBDirectory.path, 'Safety_B.zip'));
      await ownerBFile.writeAsBytes(List<int>.filled(512, 1));

      final service = LocalDataManagementService(
        documentsDirectoryProvider: () async => root,
      );
      final result = await service.clearSafetyBackups(ownerA);

      expect(result.itemCount, 1);
      expect(result.bytesFreed, 256);
      expect(await ownerBFile.exists(), isTrue);
    },
  );
}
