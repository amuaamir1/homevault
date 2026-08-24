import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/services/homevault_document_export_service.dart';
import 'package:homevault/services/homevault_file_save_service.dart';

class _MemorySaveAdapter extends HomeVaultFileSaveAdapter {
  _MemorySaveAdapter({this.shouldSave = true});

  final bool shouldSave;
  String? fileName;
  String? extension;
  Uint8List? bytes;

  @override
  Future<bool> save({
    required String dialogTitle,
    required String fileName,
    required Uint8List bytes,
    required String extension,
  }) async {
    this.fileName = fileName;
    this.extension = extension;
    this.bytes = Uint8List.fromList(bytes);
    return shouldSave;
  }
}

void main() {
  test(
    'document export validates content and generates a safe unique filename',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'homevault-p17-doc-export-',
      );
      addTearDown(() => root.delete(recursive: true));

      final source = File('${root.path}${Platform.pathSeparator}invoice.pdf');
      final pdfBytes = Uint8List.fromList(
        '%PDF-1.4\nHomeVault test\n'.codeUnits,
      );
      await source.writeAsBytes(pdfBytes, flush: true);

      final appliance = Appliance(
        id: 'a1',
        name: 'Kitchen / AC #1',
        category: 'Air conditioner',
        brand: 'HomeVault',
        createdAt: DateTime(2026, 8, 24),
      );
      final document = StoredDocument(
        id: 'd1',
        type: DocumentType.invoice,
        title: 'Purchase invoice',
        fileName: 'Invoice 2026.pdf',
        localPath: source.path,
        sizeBytes: pdfBytes.length,
        attachedAt: DateTime(2026, 8, 24),
      );
      final saver = _MemorySaveAdapter();
      final service = HomeVaultDocumentExportService(saveAdapter: saver);

      final result = await service.saveDocumentCopy(
        appliance: appliance,
        document: document,
        now: DateTime(2026, 8, 24, 20, 30, 45),
      );

      expect(result.saved, isTrue);
      expect(
        result.fileName,
        'HomeVault_Kitchen_AC_1_Invoice_2026_20260824-203045.pdf',
      );
      expect(result.fileName, isNot(contains('/')));
      expect(result.fileName, isNot(contains('\\')));
      expect(saver.fileName, result.fileName);
      expect(saver.extension, 'pdf');
      expect(saver.bytes, pdfBytes);
    },
  );

  test(
    'document export rejects file content that does not match extension',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'homevault-p17-doc-invalid-',
      );
      addTearDown(() => root.delete(recursive: true));

      final source = File('${root.path}${Platform.pathSeparator}fake.pdf');
      await source.writeAsBytes('not a pdf'.codeUnits, flush: true);

      final service = HomeVaultDocumentExportService(
        saveAdapter: _MemorySaveAdapter(),
      );
      final appliance = Appliance(
        id: 'a1',
        name: 'AC',
        category: 'Air conditioner',
        brand: 'Brand',
        createdAt: DateTime(2026, 8, 24),
      );
      final document = StoredDocument(
        fileName: 'fake.pdf',
        localPath: source.path,
        sizeBytes: await source.length(),
        attachedAt: DateTime(2026, 8, 24),
      );

      await expectLater(
        service.saveDocumentCopy(appliance: appliance, document: document),
        throwsA(isA<HomeVaultDocumentExportException>()),
      );
    },
  );

  test('cancelled file save is returned without a false success', () async {
    final root = await Directory.systemTemp.createTemp(
      'homevault-p17-doc-cancel-',
    );
    addTearDown(() => root.delete(recursive: true));

    final source = File('${root.path}${Platform.pathSeparator}manual.pdf');
    await source.writeAsBytes('%PDF-1.4\nmanual\n'.codeUnits, flush: true);

    final service = HomeVaultDocumentExportService(
      saveAdapter: _MemorySaveAdapter(shouldSave: false),
    );
    final result = await service.saveDocumentCopy(
      appliance: Appliance(
        id: 'a1',
        name: 'AC',
        category: 'Air conditioner',
        brand: 'Brand',
        createdAt: DateTime(2026, 8, 24),
      ),
      document: StoredDocument(
        type: DocumentType.userManual,
        fileName: 'manual.pdf',
        localPath: source.path,
        sizeBytes: await source.length(),
        attachedAt: DateTime(2026, 8, 24),
      ),
    );

    expect(result.saved, isFalse);
  });
}
