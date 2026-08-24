import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Settings owns sign out while Account & Data keeps backup security and deletion',
    () {
      final settings = File(
        'lib/screens/settings/settings_screen.dart',
      ).readAsStringSync();
      final accountData = File(
        'lib/screens/settings/account_data_screen.dart',
      ).readAsStringSync();

      expect(settings, contains("ValueKey('settingsAccountDataTile')"));
      expect(settings, contains("title: const Text('Account & Data')"));
      expect(settings, contains('const AccountDataScreen()'));
      expect(settings, contains("title: const Text('My profile')"));
      expect(settings, contains('const ProfileScreen()'));

      expect(settings, isNot(contains('BackupRestoreScreen')));
      expect(settings, isNot(contains('SecuritySettingsScreen')));
      expect(accountData, contains("ValueKey('accountDataBackupTile')"));
      expect(accountData, contains('const BackupRestoreScreen()'));
      expect(accountData, contains("ValueKey('accountDataSecurityTile')"));
      expect(accountData, contains('const SecuritySettingsScreen()'));

      expect(settings, contains("ValueKey('settingsSignOutTile')"));
      expect(settings, contains('lockController.prepareForSignOut()'));
      expect(settings, contains('await authController.signOut()'));
      expect(
        settings.indexOf("ValueKey('settingsSignOutTile')"),
        greaterThan(settings.indexOf("title: const Text('Service center')")),
      );

      expect(accountData, isNot(contains('accountDataSignOutTile')));
      expect(
        accountData,
        isNot(contains('lockController.prepareForSignOut()')),
      );
      expect(accountData, isNot(contains('await authController.signOut()')));

      expect(accountData, contains("title: 'Account access'"));
      expect(
        accountData,
        contains("subtitle: 'Permanently delete this HomeVault account.'"),
      );
      expect(accountData, contains("ValueKey('accountDataDeleteAccountTile')"));
      expect(accountData, contains('const AccountDeletionScreen()'));

      expect(accountData, isNot(contains('const ProfileScreen()')));
      expect(accountData, isNot(contains('accountDataProfileTile')));
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
