import 'dart:io';
import 'dart:typed_data';

import '../models/appliance.dart';
import '../models/stored_document.dart';
import '../security/homevault_file_security.dart';
import 'document_storage_service.dart';
import 'homevault_file_save_service.dart';

class HomeVaultDocumentExportResult {
  const HomeVaultDocumentExportResult({
    required this.saved,
    required this.fileName,
  });

  final bool saved;
  final String fileName;
}

class HomeVaultDocumentExportService {
  const HomeVaultDocumentExportService({
    this.saveAdapter = const FilePickerHomeVaultFileSaveAdapter(),
  });

  final HomeVaultFileSaveAdapter saveAdapter;

  Future<HomeVaultDocumentExportResult> saveDocumentCopy({
    required Appliance appliance,
    required StoredDocument document,
    DateTime? now,
  }) async {
    if (!document.isAvailableOnDevice) {
      throw const HomeVaultDocumentExportException(
        'Prepare the document on this device before saving a copy.',
      );
    }

    final source = File(document.localPath);
    if (!await source.exists()) {
      throw const HomeVaultDocumentExportException(
        'The document file is no longer available on this device. Try opening it again first.',
      );
    }

    final extension = HomeVaultFileSecurity.normalizedExtension(
      document.fileName,
    );
    if (!DocumentStorageService.allowedExtensions.contains(extension)) {
      throw const HomeVaultDocumentExportException(
        'Only PDF, JPG, JPEG, and PNG documents can be saved from HomeVault.',
      );
    }

    try {
      await HomeVaultFileSecurity.validateFile(
        source,
        fileName: document.fileName,
        maximumBytes: DocumentStorageService.maximumFileSizeBytes,
        allowedExtensions: DocumentStorageService.allowedExtensions.toSet(),
      );
    } on HomeVaultFileSecurityException catch (error) {
      throw HomeVaultDocumentExportException(error.message);
    }

    final bytes = await source.readAsBytes();
    _validateBytes(bytes, document.fileName);

    final fileName = buildExportFileName(
      appliance: appliance,
      document: document,
      now: now ?? DateTime.now(),
    );
    final saved = await saveAdapter.save(
      dialogTitle: 'Save ${document.displayTitle}',
      fileName: fileName,
      bytes: bytes,
      extension: extension,
    );

    return HomeVaultDocumentExportResult(saved: saved, fileName: fileName);
  }

  static String buildExportFileName({
    required Appliance appliance,
    required StoredDocument document,
    required DateTime now,
  }) {
    final extension = HomeVaultFileSecurity.normalizedExtension(
      document.fileName,
    );
    final originalBase = _withoutExtension(document.fileName);
    final appliancePart = _safePart(appliance.name, fallback: 'Appliance');
    final documentPart = _safePart(
      originalBase.isEmpty ? document.displayTitle : originalBase,
      fallback: 'Document',
    );
    final stamp = _timestamp(now);
    return 'HomeVault_${appliancePart}_${documentPart}_$stamp.$extension';
  }

  static void _validateBytes(Uint8List bytes, String fileName) {
    try {
      HomeVaultFileSecurity.validateBytes(
        bytes,
        fileName: fileName,
        maximumBytes: DocumentStorageService.maximumFileSizeBytes,
        allowedExtensions: DocumentStorageService.allowedExtensions.toSet(),
      );
    } on HomeVaultFileSecurityException catch (error) {
      throw HomeVaultDocumentExportException(error.message);
    }
  }

  static String _withoutExtension(String fileName) {
    final trimmed = fileName.trim();
    final dot = trimmed.lastIndexOf('.');
    return dot <= 0 ? trimmed : trimmed.substring(0, dot);
  }

  static String _safePart(String value, {required String fallback}) {
    var safe = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    safe = safe.replaceAll(RegExp(r'_+'), '_');
    safe = safe.replaceAll(RegExp(r'^_+|_+$'), '');
    if (safe.length > 48) safe = safe.substring(0, 48);
    return safe.isEmpty ? fallback : safe;
  }

  static String _timestamp(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}-'
        '${value.hour.toString().padLeft(2, '0')}'
        '${value.minute.toString().padLeft(2, '0')}'
        '${value.second.toString().padLeft(2, '0')}';
  }
}

class HomeVaultDocumentExportException implements Exception {
  const HomeVaultDocumentExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
