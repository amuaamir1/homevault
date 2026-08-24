import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/appliance.dart';
import '../models/stored_document.dart';
import '../security/homevault_file_security.dart';
import 'document_storage_service.dart';
import 'homevault_export_service.dart';
import 'homevault_file_save_service.dart';

class HomeVaultSupportPackArtifact {
  const HomeVaultSupportPackArtifact({
    required this.fileName,
    required this.bytes,
    required this.documentCount,
    required this.includesServiceHistory,
  });

  final String fileName;
  final Uint8List bytes;
  final int documentCount;
  final bool includesServiceHistory;
}

class HomeVaultSupportPackSaveResult {
  const HomeVaultSupportPackSaveResult({
    required this.saved,
    required this.fileName,
    required this.documentCount,
  });

  final bool saved;
  final String fileName;
  final int documentCount;
}

class HomeVaultSupportPackService {
  const HomeVaultSupportPackService({
    this.exportService = const HomeVaultExportService(),
    this.saveAdapter = const FilePickerHomeVaultFileSaveAdapter(),
  });

  static const int maximumDocuments = 25;
  static const int maximumSupportPackBytes = 100 * 1024 * 1024;

  final HomeVaultExportService exportService;
  final HomeVaultFileSaveAdapter saveAdapter;

  Future<HomeVaultSupportPackSaveResult> saveSupportPack({
    required Appliance appliance,
    required Iterable<StoredDocument> documents,
    required bool includeServiceHistory,
    DateTime? now,
  }) async {
    final artifact = await buildSupportPack(
      appliance: appliance,
      documents: documents,
      includeServiceHistory: includeServiceHistory,
      now: now,
    );
    final saved = await saveAdapter.save(
      dialogTitle: 'Save appliance support pack',
      fileName: artifact.fileName,
      bytes: artifact.bytes,
      extension: 'zip',
    );
    return HomeVaultSupportPackSaveResult(
      saved: saved,
      fileName: artifact.fileName,
      documentCount: artifact.documentCount,
    );
  }

  Future<HomeVaultSupportPackArtifact> buildSupportPack({
    required Appliance appliance,
    required Iterable<StoredDocument> documents,
    required bool includeServiceHistory,
    DateTime? now,
  }) async {
    final generatedAt = now ?? DateTime.now();
    final selected = _deduplicateDocuments(documents);
    if (selected.length > maximumDocuments) {
      throw const HomeVaultSupportPackException(
        'A support pack can include up to 25 documents. Select fewer files and try again.',
      );
    }

    final validatedDocuments = <({StoredDocument document, Uint8List bytes})>[];
    var uncompressedBytes = 0;

    for (final document in selected) {
      final bytes = await _readValidatedDocument(document);
      uncompressedBytes += bytes.length;
      if (uncompressedBytes > maximumSupportPackBytes) {
        throw const HomeVaultSupportPackException(
          'The selected documents are too large for one support pack. Select fewer files and try again.',
        );
      }
      validatedDocuments.add((document: document, bytes: bytes));
    }

    final summary = await exportService.createAppliancePdfArtifact(
      appliance,
      documentsForSummary: selected,
      includeServiceHistory: includeServiceHistory,
      supportPackMode: true,
    );
    uncompressedBytes += summary.bytes.length;
    if (uncompressedBytes > maximumSupportPackBytes) {
      throw const HomeVaultSupportPackException(
        'The support pack is too large to save. Select fewer documents and try again.',
      );
    }

    final usedNames = <String>{};
    final archivedDocuments =
        <({StoredDocument document, Uint8List bytes, String archiveName})>[];
    for (final item in validatedDocuments) {
      final safeName = _safeArchiveFileName(item.document.fileName);
      final uniqueName = _uniqueName(safeName, usedNames);
      archivedDocuments.add((
        document: item.document,
        bytes: item.bytes,
        archiveName: uniqueName,
      ));
    }

    final archive = Archive();
    final readme = _readme(
      appliance: appliance,
      documents: archivedDocuments
          .map(
            (item) => (document: item.document, archiveName: item.archiveName),
          )
          .toList(growable: false),
      includeServiceHistory: includeServiceHistory,
      generatedAt: generatedAt,
    );
    archive.addFile(ArchiveFile.bytes('README.txt', utf8.encode(readme)));
    archive.addFile(
      ArchiveFile.bytes('HomeVault_Appliance_Summary.pdf', summary.bytes),
    );

    for (final item in archivedDocuments) {
      archive.addFile(
        ArchiveFile.bytes('documents/${item.archiveName}', item.bytes),
      );
    }

    final encoded = ZipEncoder().encodeBytes(archive);
    final bytes = Uint8List.fromList(encoded);
    if (bytes.length > maximumSupportPackBytes) {
      throw const HomeVaultSupportPackException(
        'The support pack is too large to save. Select fewer documents and try again.',
      );
    }

    return HomeVaultSupportPackArtifact(
      fileName: _supportPackFileName(appliance, generatedAt),
      bytes: bytes,
      documentCount: selected.length,
      includesServiceHistory: includeServiceHistory,
    );
  }

  static List<StoredDocument> _deduplicateDocuments(
    Iterable<StoredDocument> documents,
  ) {
    final byId = <String, StoredDocument>{};
    for (final document in documents) {
      byId.putIfAbsent(document.id, () => document);
    }
    return byId.values.toList(growable: false);
  }

  static Future<Uint8List> _readValidatedDocument(
    StoredDocument document,
  ) async {
    if (!document.isAvailableOnDevice) {
      throw HomeVaultSupportPackException(
        '${document.displayTitle} is not available on this device yet.',
      );
    }

    final file = File(document.localPath);
    if (!await file.exists()) {
      throw HomeVaultSupportPackException(
        '${document.displayTitle} could not be found on this device.',
      );
    }

    try {
      await HomeVaultFileSecurity.validateFile(
        file,
        fileName: document.fileName,
        maximumBytes: DocumentStorageService.maximumFileSizeBytes,
        allowedExtensions: DocumentStorageService.allowedExtensions.toSet(),
      );
      final bytes = await file.readAsBytes();
      HomeVaultFileSecurity.validateBytes(
        bytes,
        fileName: document.fileName,
        maximumBytes: DocumentStorageService.maximumFileSizeBytes,
        allowedExtensions: DocumentStorageService.allowedExtensions.toSet(),
      );
      return bytes;
    } on HomeVaultFileSecurityException catch (error) {
      throw HomeVaultSupportPackException(
        '${document.displayTitle}: ${error.message}',
      );
    }
  }

  static String _readme({
    required Appliance appliance,
    required List<({StoredDocument document, String archiveName})> documents,
    required bool includeServiceHistory,
    required DateTime generatedAt,
  }) {
    final buffer = StringBuffer()
      ..writeln('HomeVault appliance support pack')
      ..writeln('================================')
      ..writeln()
      ..writeln('Appliance: ${appliance.name}')
      ..writeln('Brand: ${appliance.brand}')
      ..writeln('Model: ${appliance.modelNumber}')
      ..writeln('Generated: ${generatedAt.toLocal().toIso8601String()}')
      ..writeln()
      ..writeln(
        'This is a support package for service/warranty assistance. It is not a HomeVault backup and cannot be used to restore app data.',
      )
      ..writeln()
      ..writeln('Included:')
      ..writeln('- HomeVault_Appliance_Summary.pdf')
      ..writeln(
        '- Service history in summary: ${includeServiceHistory ? 'Yes' : 'No'}',
      )
      ..writeln('- Selected documents: ${documents.length}');

    for (final item in documents) {
      buffer.writeln(
        '  - ${item.document.displayTitle} (documents/${item.archiveName})',
      );
    }

    buffer
      ..writeln()
      ..writeln(
        'Privacy: This file may contain invoice, warranty, serial-number, contact, and service information. Store it in a private location and share it only with people you trust.',
      );
    return buffer.toString();
  }

  static String _supportPackFileName(Appliance appliance, DateTime now) {
    final appliancePart = _safePart(appliance.name, fallback: 'Appliance');
    return 'HomeVault_Support_Pack_${appliancePart}_${_timestamp(now)}.zip';
  }

  static String _safeArchiveFileName(String value) {
    final trimmed = value.trim();
    final extension = HomeVaultFileSecurity.normalizedExtension(trimmed);
    final dot = trimmed.lastIndexOf('.');
    final base = dot <= 0 ? trimmed : trimmed.substring(0, dot);
    final safeBase = _safePart(base, fallback: 'Document');
    return extension.isEmpty ? safeBase : '$safeBase.$extension';
  }

  static String _uniqueName(String fileName, Set<String> usedNames) {
    if (usedNames.add(fileName.toLowerCase())) return fileName;

    final dot = fileName.lastIndexOf('.');
    final base = dot <= 0 ? fileName : fileName.substring(0, dot);
    final extension = dot <= 0 ? '' : fileName.substring(dot);
    var suffix = 2;
    while (true) {
      final candidate = '${base}_$suffix$extension';
      if (usedNames.add(candidate.toLowerCase())) return candidate;
      suffix++;
    }
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

class HomeVaultSupportPackException implements Exception {
  const HomeVaultSupportPackException(this.message);

  final String message;

  @override
  String toString() => message;
}
