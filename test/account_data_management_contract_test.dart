import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Settings keeps profile while account data owns backup and security navigation',
    () {
      final settings = File(
        'lib/screens/settings/settings_screen.dart',
      ).readAsStringSync();

      expect(settings, contains("ValueKey('settingsAccountDataTile')"));
      expect(settings, contains("title: const Text('Account & data')"));
      expect(settings, contains('const AccountDataScreen()'));
      expect(
        settings,
        contains("'Manage your data, backups, security, and account access.'"),
      );

      expect(settings, contains("title: const Text('My profile')"));
      expect(settings, contains('const ProfileScreen()'));

      expect(settings, isNot(contains('BackupRestoreScreen')));
      expect(
        settings,
        isNot(contains("title: const Text('Backup, restore & export')")),
      );

      expect(settings, isNot(contains('SecuritySettingsScreen')));
      expect(settings, isNot(contains("title: const Text('Security')")));

      expect(settings, isNot(contains("title: const Text('Sign out')")));
      expect(settings, isNot(contains("'Delete account'")));
    },
  );

  test(
    'Account & data owns backup device storage security and lifecycle controls',
    () {
      final accountData = File(
        'lib/screens/settings/account_data_screen.dart',
      ).readAsStringSync();

      expect(accountData, contains('AccountDataSummary.fromAppliances'));
      expect(accountData, contains("ValueKey('accountDataAccountSummary')"));

      expect(accountData, contains("ValueKey('accountDataBackupTile')"));
      expect(accountData, contains('const BackupRestoreScreen()'));

      expect(accountData, contains("ValueKey('accountDataDeviceStorageTile')"));
      expect(accountData, contains('const DeviceStorageManagementScreen()'));

      expect(accountData, contains("ValueKey('accountDataSecurityTile')"));
      expect(accountData, contains('const SecuritySettingsScreen()'));

      expect(accountData, contains('lockController.prepareForSignOut()'));
      expect(accountData, contains('await authController.signOut()'));
      expect(accountData, contains('const AccountDeletionScreen()'));
      expect(accountData, contains("ValueKey('accountDataDeleteAccountTile')"));

      // Profile remains a top-level Settings destination.
      expect(accountData, isNot(contains('const ProfileScreen()')));
      expect(accountData, isNot(contains('accountDataProfileTile')));
      expect(accountData, isNot(contains("'Profile & service address'")));

      // Status-only authentication details stay removed.
      expect(accountData, isNot(contains("'Sign-in methods'")));
      expect(accountData, isNot(contains('providerLabels')));
      expect(accountData, isNot(contains('HomeVault PIN protection')));
      expect(accountData, isNot(contains('biometricLabel')));
    },
  );

  test(
    'Existing deletion service and recent-authentication guards remain intact',
    () {
      final deletionService = File(
        'lib/services/account_deletion_service.dart',
      ).readAsStringSync();
      final authController = File(
        'lib/auth/auth_controller.dart',
      ).readAsStringSync();
      final deletionScreen = File(
        'lib/screens/settings/account_deletion_screen.dart',
      ).readAsStringSync();

      expect(deletionService, contains('deleteRemoteAccountData'));
      expect(deletionService, contains('deleteLocalAccountData'));
      expect(deletionService, contains("child('users/\$ownerUid')"));
      expect(authController, contains('hasRecentSensitiveAuthentication'));
      expect(authController, contains('Future<bool> deleteCurrentAccount()'));
      expect(
        deletionScreen,
        contains('await deletionService.deleteRemoteAccountData(user.uid)'),
      );
      expect(deletionScreen, contains('clearSecurityForDeletedAccount()'));
    },
  );
}
