import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:homevault/security/security_scope_key.dart';
import 'package:homevault/services/homevault_backup_service.dart';

void main() {
  test(
    'restore cleanup protects files created by the current restore',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'homevault_restore_cleanup_test_',
      );

      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      const uid = 'restore-test-user';

      final documentDirectory = Directory(
        path.join(
          root.path,
          'homevault',
          'accounts',
          securityScopeKey(uid),
          'appliances',
          'appliance-1',
          'other',
        ),
      );
      await documentDirectory.create(recursive: true);

      final protectedFile = File(
        path.join(documentDirectory.path, 'restored_document.jpg'),
      );
      final orphanFile = File(
        path.join(documentDirectory.path, 'old_orphan.jpg'),
      );

      await protectedFile.writeAsBytes([1, 2, 3], flush: true);
      await orphanFile.writeAsBytes([4, 5, 6], flush: true);

      final service = HomeVaultBackupService(
        documentsDirectoryProvider: () async => root,
      );

      await service.cleanupUnreferencedDocuments(
        const [],
        ownerUid: uid,
        protectedFilePaths: [protectedFile.path],
      );

      expect(await protectedFile.exists(), isTrue);
      expect(await orphanFile.exists(), isFalse);
    },
  );
}
