import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Account & data is the unique location for device storage backup and security',
    () {
      final accountData = File(
        'lib/screens/settings/account_data_screen.dart',
      ).readAsStringSync();
      final settings = File(
        'lib/screens/settings/settings_screen.dart',
      ).readAsStringSync();

      expect(accountData, contains("ValueKey('accountDataBackupTile')"));
      expect(accountData, contains('const BackupRestoreScreen()'));
      expect(accountData, contains("ValueKey('accountDataDeviceStorageTile')"));
      expect(accountData, contains('const DeviceStorageManagementScreen()'));
      expect(accountData, contains("ValueKey('accountDataSecurityTile')"));
      expect(accountData, contains('const SecuritySettingsScreen()'));

      expect(accountData, isNot(contains('const ProfileScreen()')));
      expect(accountData, isNot(contains("'Sign-in methods'")));
      expect(accountData, isNot(contains('HomeVault PIN protection')));

      expect(settings, isNot(contains("'Device storage & cleanup'")));
      expect(settings, isNot(contains('BackupRestoreScreen')));
      expect(settings, isNot(contains('SecuritySettingsScreen')));
      expect(settings, contains('const ProfileScreen()'));
    },
  );

  test(
    'Device cleanup protects local-only files and does not delete cloud records or backups',
    () {
      final screen = File(
        'lib/screens/settings/device_storage_management_screen.dart',
      ).readAsStringSync();
      final store = File('lib/state/appliance_store.dart').readAsStringSync();

      expect(screen, contains('Local-only files are excluded'));
      // Source literals are intentionally wrapped across two Dart strings.
      expect(screen, contains('Cloud files and appliance records '));
      expect(screen, contains('will not be deleted. Released documents'));
      expect(screen, contains('Cloud backups are not changed here'));
      expect(screen, isNot(contains('CloudBackupScreen')));
      expect(screen, isNot(contains('Manage cloud backups')));

      expect(
        store,
        contains('document.isAvailableOnDevice && document.isAvailableInCloud'),
      );
      expect(store, contains("target.document.copyWith(localPath: '')"));
      expect(
        store,
        contains('_localDocumentCachePolicy.markEvicted(cloudPaths)'),
      );
    },
  );

  test(
    'Released cloud copies stay cloud-only until explicitly opened again',
    () {
      final store = File('lib/state/appliance_store.dart').readAsStringSync();
      final policy = File(
        'lib/services/local_document_cache_policy.dart',
      ).readAsStringSync();

      expect(store, contains('_evictedCloudDocumentPaths.contains('));
      expect(store, contains('_markDocumentCacheAvailableSafely'));
      expect(policy, contains('local_document_cache_policy.json'));
      expect(policy, contains("'ownerScope': _ownerScope"));
    },
  );

  test('Production wires persistent owner-scoped local cache policy', () {
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(
      mainSource,
      contains('localDocumentCachePolicy: FileLocalDocumentCachePolicy()'),
    );
  });

  test(
    'Local safety backup cleanup is account scoped and account deletion still removes it',
    () {
      final service = File(
        'lib/services/local_data_management_service.dart',
      ).readAsStringSync();
      final deletion = File(
        'lib/services/account_deletion_service.dart',
      ).readAsStringSync();

      expect(service, contains("'safety_backups'"));
      expect(service, contains('securityScopeKey(ownerUid)'));
      expect(deletion, contains("'safety_backups'"));
      expect(
        deletion,
        contains("path.join(homeVaultRoot.path, 'data', 'users', scope)"),
      );
    },
  );

  test('Existing cloud-backup deletion remains recent-auth protected', () {
    final cloudBackup = File(
      'lib/screens/backup/cloud_backup_screen.dart',
    ).readAsStringSync();

    expect(cloudBackup, contains('verifySensitiveAction('));
    expect(
      cloudBackup,
      contains('Deleting this cloud restore point is permanent'),
    );
  });
}
