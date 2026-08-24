import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Document Vault exposes secure Save a copy actions', () {
    final screen = File(
      'lib/screens/documents/documents_screen.dart',
    ).readAsStringSync();
    final tile = File(
      'lib/widgets/stored_document_tile.dart',
    ).readAsStringSync();
    final details = File(
      'lib/screens/documents/document_details_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('HomeVaultDocumentExportService'));
    expect(screen, contains('_saveDocumentCopy'));
    expect(screen, contains('.downloadDocument(applianceId, document.id)'));
    expect(
      screen,
      contains('Document copy saved. You can share it later from Files.'),
    );
    expect(tile, contains("title: Text('Save a copy')"));
    expect(tile, contains("value: 'saveCopy'"));
    expect(details, contains('DocumentDetailsAction.saveCopy'));
    expect(details, contains("ValueKey('documentDetailsSaveCopyButton')"));
  });

  test('stale local document paths can recover from cloud before export', () {
    final store = File('lib/state/appliance_store.dart').readAsStringSync();

    expect(store, contains('final localFile = File(document.localPath);'));
    expect(store, contains('if (await localFile.exists())'));
    expect(
      store,
      contains("'The document file is no longer available on this device.'"),
    );
  });

  test('support pack is selective Save-only and not a backup', () {
    final backupScreen = File(
      'lib/screens/backup/backup_restore_screen.dart',
    ).readAsStringSync();
    final supportScreen = File(
      'lib/screens/backup/appliance_support_pack_screen.dart',
    ).readAsStringSync();
    final service = File(
      'lib/services/homevault_support_pack_service.dart',
    ).readAsStringSync();

    expect(backupScreen, contains("ValueKey('p17SupportPackTile')"));
    expect(supportScreen, contains("ValueKey('p17SaveSupportPackButton')"));
    expect(
      supportScreen,
      contains("ValueKey('p17SupportPackServiceHistoryToggle')"),
    );
    expect(supportScreen, contains('Off by default'));
    expect(supportScreen, contains('Select only the document files you want'));
    expect(service, contains('maximumDocuments = 25'));
    expect(service, contains('maximumSupportPackBytes = 100 * 1024 * 1024'));
    expect(service, contains("ArchiveFile.bytes('README.txt'"));
    expect(service, contains("'HomeVault_Appliance_Summary.pdf'"));
    expect(
      service,
      contains(r"ArchiveFile.bytes('documents/${item.archiveName}'"),
    );
    expect(service, contains('not a HomeVault backup'));
  });

  test('export safety validates content and never exposes internal paths', () {
    final documentExport = File(
      'lib/services/homevault_document_export_service.dart',
    ).readAsStringSync();
    final supportPack = File(
      'lib/services/homevault_support_pack_service.dart',
    ).readAsStringSync();
    final saveService = File(
      'lib/services/homevault_file_save_service.dart',
    ).readAsStringSync();

    expect(documentExport, contains('HomeVaultFileSecurity.validateFile'));
    expect(documentExport, contains('HomeVaultFileSecurity.validateBytes'));
    expect(documentExport, contains(r'HomeVault_${appliancePart}_'));
    expect(supportPack, contains('_uniqueName'));
    expect(supportPack, contains('_safeArchiveFileName'));
    expect(saveService, contains('FilePicker.platform.saveFile'));
    expect(saveService, contains('return savedPath != null'));
    expect(documentExport, isNot(contains("ScaffoldMessenger")));
  });
}
