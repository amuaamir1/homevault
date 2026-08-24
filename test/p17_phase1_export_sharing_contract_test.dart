import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P17 Phase 1 reports are Save-only', () {
    final screen = File(
      'lib/screens/backup/backup_restore_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('Save CSV reports to Files.'));

    for (final marker in [
      "saveKey: 'p17SaveInventoryButton'",
      "saveKey: 'p17SaveWarrantyButton'",
      "saveKey: 'p17SaveServiceCostButton'",
      "ValueKey('p17SaveAppliancePdfButton')",
    ]) {
      expect(screen, contains(marker));
    }

    expect(screen, contains('key: ValueKey(saveKey)'));
    expect(screen, contains("tooltip: 'Save'"));
    expect(
      screen,
      contains('Choose one appliance, then save its printable summary.'),
    );

    for (final forbidden in [
      'p17ShareInventoryButton',
      'p17ShareWarrantyButton',
      'p17ShareServiceCostButton',
      'p17ShareAppliancePdfButton',
      '_shareInventory',
      '_shareWarrantyReport',
      '_shareServiceReport',
      '_shareAppliancePdf',
      '_runShare',
      '_shareService',
      'shareKey:',
      '_ExportShareTile',
      'Icons.share_outlined',
    ]) {
      expect(screen, isNot(contains(forbidden)));
    }
  });

  test('full HomeVault ZIP backup remains Save-only', () {
    final screen = File(
      'lib/screens/backup/backup_restore_screen.dart',
    ).readAsStringSync();

    expect(screen, contains("title: const Text('Create full backup')"));
    expect(screen, contains('onTap: _createBackup'));
    expect(screen, isNot(contains('_shareBackup')));
    expect(screen, isNot(contains('p17ShareBackupButton')));
  });

  test('report screen no longer owns native share temp-file lifecycle', () {
    final screen = File(
      'lib/screens/backup/backup_restore_screen.dart',
    ).readAsStringSync();

    expect(screen, isNot(contains('homevault_share_service.dart')));
    expect(screen, isNot(contains('_cleanupStaleShareFiles')));
    expect(screen, isNot(contains('HomeVaultShareService')));
  });

  test(
    'native share foundation remains available for later document sharing',
    () {
      final service = File(
        'lib/services/homevault_share_service.dart',
      ).readAsStringSync();
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(service, contains('SharePlus.instance.share'));
      expect(service, contains("shareDirectoryName = 'homevault_share'"));
      expect(service, isNot(contains("'application/zip'")));

      expect(pubspec, contains('share_plus: 12.0.2'));
      expect(pubspec, isNot(contains('share_plus: 13.3.0')));
      expect(pubspec, contains('device_info_plus: 12.4.0'));
    },
  );
}
