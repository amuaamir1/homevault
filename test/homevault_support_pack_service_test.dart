import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/services/homevault_file_save_service.dart';
import 'package:homevault/services/homevault_support_pack_service.dart';

class _MemorySaveAdapter extends HomeVaultFileSaveAdapter {
  String? fileName;
  Uint8List? bytes;

  @override
  Future<bool> save({
    required String dialogTitle,
    required String fileName,
    required Uint8List bytes,
    required String extension,
  }) async {
    this.fileName = fileName;
    this.bytes = Uint8List.fromList(bytes);
    return true;
  }
}

void main() {
  test(
    'support pack includes summary, README, selected files and no restore manifest',
    () async {
      final root = await Directory.systemTemp.createTemp('homevault-p17-pack-');
      addTearDown(() => root.delete(recursive: true));

      final first = File('${root.path}${Platform.pathSeparator}one.pdf');
      final second = File('${root.path}${Platform.pathSeparator}two.pdf');
      await first.writeAsBytes('%PDF-1.4\ninvoice\n'.codeUnits, flush: true);
      await second.writeAsBytes('%PDF-1.4\nwarranty\n'.codeUnits, flush: true);

      final invoice = StoredDocument(
        id: 'invoice',
        type: DocumentType.invoice,
        title: 'Invoice',
        fileName: 'document.pdf',
        localPath: first.path,
        sizeBytes: await first.length(),
        attachedAt: DateTime(2026, 8, 24),
      );
      final warranty = StoredDocument(
        id: 'warranty',
        type: DocumentType.warrantyCard,
        title: 'Warranty card',
        fileName: 'document.pdf',
        localPath: second.path,
        sizeBytes: await second.length(),
        attachedAt: DateTime(2026, 8, 24),
      );
      final appliance = Appliance(
        id: 'a1',
        name: 'Bedroom AC',
        category: 'Air conditioner',
        brand: 'Brand',
        modelNumber: 'M-1',
        createdAt: DateTime(2026, 8, 24),
        invoiceDocument: invoice,
        warrantyDocument: warranty,
      );

      final service = HomeVaultSupportPackService(
        saveAdapter: _MemorySaveAdapter(),
      );
      final artifact = await service.buildSupportPack(
        appliance: appliance,
        documents: [invoice, warranty],
        includeServiceHistory: false,
        now: DateTime(2026, 8, 24, 20, 45, 1),
      );

      expect(
        artifact.fileName,
        'HomeVault_Support_Pack_Bedroom_AC_20260824-204501.zip',
      );
      expect(artifact.documentCount, 2);
      expect(artifact.includesServiceHistory, isFalse);

      final archive = ZipDecoder().decodeBytes(artifact.bytes, verify: true);
      final names = archive.files.map((file) => file.name).toSet();
      expect(names, contains('README.txt'));
      expect(names, contains('HomeVault_Appliance_Summary.pdf'));
      expect(names, contains('documents/document.pdf'));
      expect(names, contains('documents/document_2.pdf'));
      expect(names, isNot(contains('manifest.json')));
      expect(names.any((name) => name.contains('backup')), isFalse);

      final readme = archive.files
          .firstWhere((file) => file.name == 'README.txt')
          .readBytes();
      if (readme == null) {
        fail('README.txt did not contain readable bytes.');
      }
      final readmeText = String.fromCharCodes(readme);
      expect(readmeText, contains('not a HomeVault backup'));
      expect(readmeText, contains('Service history in summary: No'));
      expect(readmeText, contains('Selected documents: 2'));
    },
  );

  test('support pack rejects an invalid selected document', () async {
    final root = await Directory.systemTemp.createTemp(
      'homevault-p17-pack-invalid-',
    );
    addTearDown(() => root.delete(recursive: true));

    final invalid = File('${root.path}${Platform.pathSeparator}fake.pdf');
    await invalid.writeAsBytes('not pdf content'.codeUnits, flush: true);

    final document = StoredDocument(
      id: 'bad',
      type: DocumentType.invoice,
      title: 'Invoice',
      fileName: 'invoice.pdf',
      localPath: invalid.path,
      sizeBytes: await invalid.length(),
      attachedAt: DateTime(2026, 8, 24),
    );
    final appliance = Appliance(
      id: 'a1',
      name: 'AC',
      category: 'Air conditioner',
      brand: 'Brand',
      createdAt: DateTime(2026, 8, 24),
      invoiceDocument: document,
    );

    await expectLater(
      const HomeVaultSupportPackService().buildSupportPack(
        appliance: appliance,
        documents: [document],
        includeServiceHistory: false,
      ),
      throwsA(isA<HomeVaultSupportPackException>()),
    );
  });
}
