import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P17 report exports are Save-only', () {
    final screen = File(
      'lib/screens/backup/backup_restore_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('Save CSV reports to Files.'));
    expect(screen, contains("saveKey: 'p17SaveInventoryButton'"));
    expect(screen, contains("saveKey: 'p17SaveWarrantyButton'"));
    expect(screen, contains("saveKey: 'p17SaveServiceCostButton'"));
    expect(screen, contains("ValueKey('p17SaveAppliancePdfButton')"));
    expect(
      screen,
      contains('Choose one appliance, then save its printable summary.'),
    );

    for (final marker in [
      'p17ShareInventoryButton',
      'p17ShareWarrantyButton',
      'p17ShareServiceCostButton',
      'p17ShareAppliancePdfButton',
      '_shareInventory',
      '_shareWarrantyReport',
      '_shareServiceReport',
      '_shareAppliancePdf',
      '_runShare',
      'Icons.share_outlined',
    ]) {
      expect(screen, isNot(contains(marker)));
    }
  });

  test(
    'native in-app sharing dependency was removed from Save-only exports',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, isNot(contains('share_plus:')));
      expect(pubspec, isNot(contains('cross_file:')));
      expect(
        File('lib/services/homevault_share_service.dart').existsSync(),
        isFalse,
      );
    },
  );

  test(
    'full HomeVault backup remains separate from appliance support packs',
    () {
      final screen = File(
        'lib/screens/backup/backup_restore_screen.dart',
      ).readAsStringSync();

      expect(screen, contains("title: const Text('Create full backup')"));
      expect(screen, contains('onTap: _createBackup'));
      expect(screen, contains("ValueKey('p17SupportPackTile')"));
      expect(screen, contains("title: const Text('Appliance support pack')"));
    },
  );
}
