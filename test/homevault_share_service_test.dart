import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/services/homevault_export_service.dart';
import 'package:homevault/services/homevault_share_service.dart';
import 'package:path/path.dart' as path;

class _FakeNativeShareGateway implements HomeVaultNativeShareGateway {
  String? filePath;
  String? mimeType;
  String? title;
  String? subject;
  int calls = 0;
  HomeVaultShareStatus nextStatus = HomeVaultShareStatus.success;

  @override
  Future<HomeVaultShareResult> shareFile({
    required String filePath,
    required String mimeType,
    required String title,
    required String subject,
  }) async {
    calls++;
    this.filePath = filePath;
    this.mimeType = mimeType;
    this.title = title;
    this.subject = subject;
    return HomeVaultShareResult(nextStatus);
  }
}

void main() {
  test(
    'share service writes controlled temp file and removes stale files',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'homevault-p17-share-',
      );
      addTearDown(() => root.delete(recursive: true));

      final shareDir = Directory(
        path.join(root.path, HomeVaultShareService.shareDirectoryName),
      );
      await shareDir.create(recursive: true);

      final stale = File(path.join(shareDir.path, 'old-report.csv'));
      await stale.writeAsString('old');
      final now = DateTime(2026, 8, 24, 19, 30);
      await stale.setLastModified(now.subtract(const Duration(days: 2)));

      final gateway = _FakeNativeShareGateway();
      final service = HomeVaultShareService(
        nativeShareGateway: gateway,
        temporaryDirectoryProvider: () async => root,
        clock: () => now,
      );

      final result = await service.shareArtifact(
        HomeVaultExportArtifact(
          fileName: '../HomeVault Inventory.csv',
          displayName: 'Appliance inventory',
          mimeType: 'text/csv',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        ),
      );

      expect(result.status, HomeVaultShareStatus.success);
      expect(gateway.calls, 1);
      expect(gateway.mimeType, 'text/csv');
      expect(gateway.title, 'Share Appliance inventory');
      expect(gateway.subject, 'HomeVault Appliance inventory');

      final sharedPath = gateway.filePath!;
      expect(File(sharedPath).existsSync(), isTrue);
      expect(path.dirname(sharedPath), shareDir.path);
      expect(path.basename(sharedPath), isNot(contains('..')));
      expect(path.basename(sharedPath), isNot(contains('/')));
      expect(path.basename(sharedPath), isNot(contains(r'\')));
      expect(await File(sharedPath).readAsBytes(), [1, 2, 3, 4]);
      expect(await stale.exists(), isFalse);
    },
  );

  test('Phase 1 rejects ZIP backup sharing', () async {
    final root = await Directory.systemTemp.createTemp('homevault-p17-zip-');
    addTearDown(() => root.delete(recursive: true));

    final gateway = _FakeNativeShareGateway();
    final service = HomeVaultShareService(
      nativeShareGateway: gateway,
      temporaryDirectoryProvider: () async => root,
    );

    await expectLater(
      service.shareArtifact(
        HomeVaultExportArtifact(
          fileName: 'HomeVault_Backup.zip',
          displayName: 'Full backup',
          mimeType: 'application/zip',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      ),
      throwsArgumentError,
    );

    expect(gateway.calls, 0);
  });

  test('report MIME type must match its file extension', () async {
    final root = await Directory.systemTemp.createTemp('homevault-p17-type-');
    addTearDown(() => root.delete(recursive: true));

    final gateway = _FakeNativeShareGateway();
    final service = HomeVaultShareService(
      nativeShareGateway: gateway,
      temporaryDirectoryProvider: () async => root,
    );

    await expectLater(
      service.shareArtifact(
        HomeVaultExportArtifact(
          fileName: 'HomeVault_Report.pdf',
          displayName: 'Report',
          mimeType: 'text/csv',
          bytes: Uint8List.fromList([1]),
        ),
      ),
      throwsArgumentError,
    );

    expect(gateway.calls, 0);
  });
}
