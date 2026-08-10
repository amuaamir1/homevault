import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../core/app_build_info.dart';
import '../models/appliance.dart';
import '../security/security_scope_key.dart';
import '../models/backup_models.dart';
import '../models/stored_document.dart';

class HomeVaultBackupService {
  HomeVaultBackupService({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  static const String backupFormat = 'homevault-backup';
  static const int backupSchemaVersion = 2;
  static const String appVersion = AppBuildInfo.version;
  static const String _manifestName = 'manifest.json';
  static const String _legacyOwnerMarkerName = '.homevault_owner';

  final Future<Directory> Function() _documentsDirectoryProvider;

  Future<BackupCreationResult?> createAndSaveBackup(
    Iterable<Appliance> appliances, {
    String? ownerUid,
  }) async {
    final archiveData = await buildBackup(appliances, ownerUid: ownerUid);
    final fileName = _backupFileName();

    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save HomeVault backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      bytes: archiveData.bytes,
    );

    if (savedPath == null) {
      return null;
    }

    return BackupCreationResult(
      fileName: fileName,
      applianceCount: archiveData.applianceCount,
      documentCount: archiveData.documentCount,
      missingDocuments: archiveData.missingDocuments,
    );
  }

  Future<String?> createSafetyBackup(
    Iterable<Appliance> appliances, {
    required String ownerUid,
  }) async {
    final applianceList = appliances.toList(growable: false);
    if (applianceList.isEmpty) return null;

    final archiveData = await buildBackup(applianceList, ownerUid: ownerUid);
    final documentsDirectory = await _documentsDirectoryProvider();
    final directory = Directory(
      path.join(
        documentsDirectory.path,
        'homevault',
        'safety_backups',
        securityScopeKey(ownerUid),
      ),
    );
    await directory.create(recursive: true);

    final file = File(
      path.join(
        directory.path,
        'Safety_${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );
    await file.writeAsBytes(archiveData.bytes, flush: true);

    final backups = directory.listSync().whereType<File>().toList()
      ..sort(
        (first, second) =>
            second.lastModifiedSync().compareTo(first.lastModifiedSync()),
      );
    for (final oldBackup in backups.skip(3)) {
      try {
        await oldBackup.delete();
      } catch (_) {
        // Keeping an older safety backup is harmless.
      }
    }

    return file.path;
  }

  Future<BackupSelection?> pickBackup() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select a HomeVault backup',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final picked = result.files.single;
    Uint8List? bytes = picked.bytes;
    final pickedPath = picked.path;

    if (bytes == null && pickedPath != null && pickedPath.trim().isNotEmpty) {
      bytes = await File(pickedPath).readAsBytes();
    }

    if (bytes == null || bytes.isEmpty) {
      throw const BackupFormatException(
        'The selected backup file could not be read.',
      );
    }

    return inspectBackupBytes(bytes, fileName: picked.name);
  }

  Future<BackupArchiveData> buildBackup(
    Iterable<Appliance> appliances, {
    String? ownerUid,
  }) async {
    final applianceList = appliances.toList(growable: false);
    final archive = Archive();
    final state = _BackupBuildState(archive);
    final applianceJson = <Map<String, dynamic>>[];

    for (final appliance in applianceList) {
      applianceJson.add(await _prepareApplianceForBackup(appliance, state));
    }

    final manifest = <String, dynamic>{
      'format': backupFormat,
      'schemaVersion': backupSchemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'appVersion': appVersion,
      if (ownerUid?.trim().isNotEmpty == true)
        'ownerFingerprint': securityScopeKey(ownerUid!),
      'applianceCount': applianceList.length,
      'documentCount': state.documentCount,
      'missingDocuments': state.missingDocuments,
      'appliances': applianceJson,
    };

    archive.addFile(
      ArchiveFile.bytes(_manifestName, utf8.encode(jsonEncode(manifest))),
    );

    final bytes = ZipEncoder().encodeBytes(archive);
    return BackupArchiveData(
      bytes: bytes,
      applianceCount: applianceList.length,
      documentCount: state.documentCount,
      missingDocuments: state.missingDocuments.length,
    );
  }

  BackupSelection inspectBackupBytes(
    Uint8List bytes, {
    required String fileName,
  }) {
    final decoded = _decodeArchive(bytes);
    final manifest = decoded.manifest;
    final applianceData = _requiredApplianceData(manifest);

    for (final item in applianceData) {
      try {
        Appliance.fromJson(Map<String, dynamic>.from(item));
      } catch (error) {
        throw BackupFormatException(
          'The backup contains an invalid appliance record.',
          error,
        );
      }
    }

    final createdAt = DateTime.tryParse('${manifest['createdAt']}');
    if (createdAt == null) {
      throw const BackupFormatException(
        'The backup creation date is missing or invalid.',
      );
    }

    final declaredDocuments = _readNonNegativeInt(manifest['documentCount']);
    final omittedDocuments = manifest['missingDocuments'] is List
        ? (manifest['missingDocuments'] as List).length
        : 0;
    final missingArchiveEntries = _countMissingArchiveDocuments(
      applianceData,
      decoded.files,
    );

    return BackupSelection(
      bytes: bytes,
      preview: BackupPreview(
        fileName: fileName,
        createdAt: createdAt.toLocal(),
        appVersion: '${manifest['appVersion'] ?? 'Unknown'}',
        schemaVersion: _readNonNegativeInt(manifest['schemaVersion']),
        applianceCount: applianceData.length,
        documentCount: declaredDocuments,
        missingDocumentCount: omittedDocuments + missingArchiveEntries,
        ownerFingerprint: '${manifest['ownerFingerprint'] ?? ''}'.trim().isEmpty
            ? null
            : '${manifest['ownerFingerprint']}',
      ),
    );
  }

  Future<PreparedRestore> prepareRestore({
    required BackupSelection selection,
    required Iterable<Appliance> existingAppliances,
    required RestoreMode mode,
    String? currentOwnerUid,
  }) async {
    final decoded = _decodeArchive(selection.bytes);
    final manifest = decoded.manifest;
    final applianceData = _requiredApplianceData(manifest);
    final backupOwner = '${manifest['ownerFingerprint'] ?? ''}'.trim();
    if (backupOwner.isNotEmpty &&
        currentOwnerUid?.trim().isNotEmpty == true &&
        backupOwner != securityScopeKey(currentOwnerUid!)) {
      throw const BackupFormatException(
        'This backup belongs to a different HomeVault account.',
      );
    }

    final existing = existingAppliances.toList(growable: false);
    final duplicateIds = existing.map((item) => item.id).toSet();
    final duplicateSerials = existing
        .map(_serialKey)
        .whereType<String>()
        .toSet();
    final selectedIds = <String>{};
    final selectedSerials = <String>{};
    final candidates = <Map<String, dynamic>>[];
    var skippedDuplicates = 0;

    for (final item in applianceData) {
      final raw = Map<String, dynamic>.from(item);
      final id = '${raw['id'] ?? ''}'.trim();
      if (id.isEmpty) {
        throw const BackupFormatException(
          'The backup contains an appliance without an ID.',
        );
      }

      final serialKey = _serialKeyFromJson(raw);
      final duplicateWithinBackup =
          selectedIds.contains(id) ||
          (serialKey != null && selectedSerials.contains(serialKey));
      final duplicateExisting =
          mode == RestoreMode.merge &&
          (duplicateIds.contains(id) ||
              (serialKey != null && duplicateSerials.contains(serialKey)));

      if (duplicateWithinBackup || duplicateExisting) {
        skippedDuplicates++;
        continue;
      }

      candidates.add(raw);
      selectedIds.add(id);
      if (serialKey != null) {
        selectedSerials.add(serialKey);
      }
    }

    final documentsDirectory = await _documentsDirectoryProvider();
    final restoreApplianceRoot = _applianceDocumentRoot(
      documentsDirectory,
      currentOwnerUid,
    );
    final createdFilePaths = <String>[];
    final restoredAppliances = <Appliance>[];
    final restoreStamp = DateTime.now().microsecondsSinceEpoch;
    var restoredDocuments = 0;
    var missingDocuments = manifest['missingDocuments'] is List
        ? (manifest['missingDocuments'] as List).length
        : 0;

    try {
      for (final candidate in candidates) {
        final applianceJson = _deepJsonCopy(candidate);
        final applianceId = '${applianceJson['id']}';

        final photoResult = await _restoreDocumentMap(
          _mapOrNull(applianceJson['appliancePhotoDocument']),
          applianceId: applianceId,
          decodedFiles: decoded.files,
          applianceRoot: restoreApplianceRoot,
          restoreStamp: restoreStamp,
          createdFilePaths: createdFilePaths,
        );
        applianceJson['appliancePhotoDocument'] = photoResult.documentJson;
        restoredDocuments += photoResult.restoredCount;
        missingDocuments += photoResult.missingCount;

        final invoiceResult = await _restoreDocumentMap(
          _mapOrNull(applianceJson['invoiceDocument']),
          applianceId: applianceId,
          decodedFiles: decoded.files,
          applianceRoot: restoreApplianceRoot,
          restoreStamp: restoreStamp,
          createdFilePaths: createdFilePaths,
        );
        applianceJson['invoiceDocument'] = invoiceResult.documentJson;
        restoredDocuments += invoiceResult.restoredCount;
        missingDocuments += invoiceResult.missingCount;

        final warrantyResult = await _restoreDocumentMap(
          _mapOrNull(applianceJson['warrantyDocument']),
          applianceId: applianceId,
          decodedFiles: decoded.files,
          applianceRoot: restoreApplianceRoot,
          restoreStamp: restoreStamp,
          createdFilePaths: createdFilePaths,
        );
        applianceJson['warrantyDocument'] = warrantyResult.documentJson;
        restoredDocuments += warrantyResult.restoredCount;
        missingDocuments += warrantyResult.missingCount;

        final extendedWarrantyResult = await _restoreDocumentMap(
          _mapOrNull(applianceJson['extendedWarrantyDocument']),
          applianceId: applianceId,
          decodedFiles: decoded.files,
          applianceRoot: restoreApplianceRoot,
          restoreStamp: restoreStamp,
          createdFilePaths: createdFilePaths,
        );
        applianceJson['extendedWarrantyDocument'] =
            extendedWarrantyResult.documentJson;
        restoredDocuments += extendedWarrantyResult.restoredCount;
        missingDocuments += extendedWarrantyResult.missingCount;

        final amcResult = await _restoreDocumentMap(
          _mapOrNull(applianceJson['amcDocument']),
          applianceId: applianceId,
          decodedFiles: decoded.files,
          applianceRoot: restoreApplianceRoot,
          restoreStamp: restoreStamp,
          createdFilePaths: createdFilePaths,
        );
        applianceJson['amcDocument'] = amcResult.documentJson;
        restoredDocuments += amcResult.restoredCount;
        missingDocuments += amcResult.missingCount;

        final restoredAdditional = <Map<String, dynamic>>[];
        final additional = applianceJson['additionalDocuments'];
        if (additional is List) {
          for (final item in additional.whereType<Map>()) {
            final result = await _restoreDocumentMap(
              Map<String, dynamic>.from(item),
              applianceId: applianceId,
              decodedFiles: decoded.files,
              applianceRoot: restoreApplianceRoot,
              restoreStamp: restoreStamp,
              createdFilePaths: createdFilePaths,
            );
            if (result.documentJson != null) {
              restoredAdditional.add(result.documentJson!);
            }
            restoredDocuments += result.restoredCount;
            missingDocuments += result.missingCount;
          }
        }
        applianceJson['additionalDocuments'] = restoredAdditional;

        final restoredServices = <Map<String, dynamic>>[];
        final services = applianceJson['serviceRecords'];
        if (services is List) {
          for (final item in services.whereType<Map>()) {
            final serviceJson = Map<String, dynamic>.from(item);

            final receiptResult = await _restoreDocumentMap(
              _mapOrNull(serviceJson['receiptDocument']),
              applianceId: applianceId,
              decodedFiles: decoded.files,
              applianceRoot: restoreApplianceRoot,
              restoreStamp: restoreStamp,
              createdFilePaths: createdFilePaths,
            );
            serviceJson['receiptDocument'] = receiptResult.documentJson;
            restoredDocuments += receiptResult.restoredCount;
            missingDocuments += receiptResult.missingCount;

            final reportResult = await _restoreDocumentMap(
              _mapOrNull(serviceJson['reportDocument']),
              applianceId: applianceId,
              decodedFiles: decoded.files,
              applianceRoot: restoreApplianceRoot,
              restoreStamp: restoreStamp,
              createdFilePaths: createdFilePaths,
            );
            serviceJson['reportDocument'] = reportResult.documentJson;
            restoredDocuments += reportResult.restoredCount;
            missingDocuments += reportResult.missingCount;

            restoredServices.add(serviceJson);
          }
        }
        applianceJson['serviceRecords'] = restoredServices;

        final appliance = Appliance.fromJson(applianceJson);
        if (appliance.id.isEmpty) {
          throw const BackupFormatException(
            'A restored appliance has an invalid ID.',
          );
        }
        restoredAppliances.add(appliance);
      }
    } catch (error) {
      await cleanupCreatedFiles(createdFilePaths);
      if (error is BackupFormatException) {
        rethrow;
      }
      throw BackupFormatException(
        'HomeVault could not prepare the backup for restoration.',
        error,
      );
    }

    return PreparedRestore(
      appliances: List.unmodifiable(restoredAppliances),
      createdFilePaths: List.unmodifiable(createdFilePaths),
      importedAppliances: restoredAppliances.length,
      skippedDuplicates: skippedDuplicates,
      restoredDocuments: restoredDocuments,
      missingDocuments: missingDocuments,
    );
  }

  Future<void> cleanupCreatedFiles(Iterable<String> filePaths) async {
    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Cleanup is best effort and must not replace the original error.
      }
    }
  }

  Future<void> cleanupUnreferencedDocuments(
    Iterable<Appliance> appliances, {
    String? ownerUid,
    Iterable<String> protectedFilePaths = const [],
  }) async {
    final documentsDirectory = await _documentsDirectoryProvider();
    final roots = <Directory>[
      _applianceDocumentRoot(documentsDirectory, ownerUid),
    ];

    if (await _ownsLegacyDocumentRoot(documentsDirectory, ownerUid)) {
      roots.add(
        Directory(
          path.join(documentsDirectory.path, 'homevault', 'appliances'),
        ),
      );
    }

    final referenced = <String>{
      ...appliances
          .expand((appliance) => appliance.allAttachments)
          .where((document) => document.localPath.trim().isNotEmpty)
          .map(
            (document) =>
                path.normalize(File(document.localPath).absolute.path),
          ),
      ...protectedFilePaths
          .where((filePath) => filePath.trim().isNotEmpty)
          .map((filePath) => path.normalize(File(filePath).absolute.path)),
    };

    for (final applianceRoot in roots) {
      if (!await applianceRoot.exists()) continue;

      await for (final entity in applianceRoot.list(recursive: true)) {
        if (entity is! File ||
            path.basename(entity.path) == _legacyOwnerMarkerName) {
          continue;
        }
        final normalised = path.normalize(entity.absolute.path);
        if (!referenced.contains(normalised)) {
          try {
            await entity.delete();
          } catch (_) {
            // Old orphaned files can be retried during a later restore.
          }
        }
      }

      final directories = <Directory>[];
      await for (final entity in applianceRoot.list(recursive: true)) {
        if (entity is Directory) {
          directories.add(entity);
        }
      }
      directories.sort((a, b) => b.path.length.compareTo(a.path.length));
      for (final directory in directories) {
        try {
          if (await directory.list().isEmpty) {
            await directory.delete();
          }
        } catch (_) {
          // Empty-directory cleanup is optional.
        }
      }
    }
  }

  Future<Map<String, dynamic>> _prepareApplianceForBackup(
    Appliance appliance,
    _BackupBuildState state,
  ) async {
    final json = Map<String, dynamic>.from(appliance.toJson());

    json['appliancePhotoDocument'] = await _prepareDocumentForBackup(
      appliance.appliancePhotoDocument,
      appliance: appliance,
      state: state,
    );
    json['invoiceDocument'] = await _prepareDocumentForBackup(
      appliance.invoiceDocument,
      appliance: appliance,
      state: state,
    );
    json['warrantyDocument'] = await _prepareDocumentForBackup(
      appliance.warrantyDocument,
      appliance: appliance,
      state: state,
    );
    json['extendedWarrantyDocument'] = await _prepareDocumentForBackup(
      appliance.extendedWarrantyDocument,
      appliance: appliance,
      state: state,
    );
    json['amcDocument'] = await _prepareDocumentForBackup(
      appliance.amcDocument,
      appliance: appliance,
      state: state,
    );

    final additional = <Map<String, dynamic>>[];
    for (final document in appliance.additionalDocuments) {
      final prepared = await _prepareDocumentForBackup(
        document,
        appliance: appliance,
        state: state,
      );
      if (prepared != null) {
        additional.add(prepared);
      }
    }
    json['additionalDocuments'] = additional;

    final services = <Map<String, dynamic>>[];
    for (final record in appliance.serviceRecords) {
      final serviceJson = Map<String, dynamic>.from(record.toJson());
      serviceJson['receiptDocument'] = await _prepareDocumentForBackup(
        record.receiptDocument,
        appliance: appliance,
        state: state,
      );
      serviceJson['reportDocument'] = await _prepareDocumentForBackup(
        record.reportDocument,
        appliance: appliance,
        state: state,
      );
      services.add(serviceJson);
    }
    json['serviceRecords'] = services;

    return json;
  }

  Future<Map<String, dynamic>?> _prepareDocumentForBackup(
    StoredDocument? document, {
    required Appliance appliance,
    required _BackupBuildState state,
  }) async {
    if (document == null) {
      return null;
    }

    final source = File(document.localPath);
    if (document.localPath.trim().isEmpty || !await source.exists()) {
      state.missingDocuments.add({
        'applianceId': appliance.id,
        'applianceName': appliance.name,
        'documentId': document.id,
        'documentTitle': document.displayTitle,
      });
      return null;
    }

    final data = await source.readAsBytes();
    final archivePath = state.uniqueArchivePath(
      applianceId: appliance.id,
      documentId: document.id,
      fileName: document.fileName,
    );
    state.archive.addFile(ArchiveFile.bytes(archivePath, data));
    state.documentCount++;

    return <String, dynamic>{
      ...document.toJson(),
      'localPath': archivePath,
      'sizeBytes': data.length,
    };
  }

  _DecodedBackup _decodeArchive(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final files = <String, ArchiveFile>{};

      for (final entry in archive) {
        final name = entry.name.replaceAll('\\', '/');
        if (!_isSafeArchivePath(name)) {
          throw const BackupFormatException(
            'The backup contains an unsafe file path.',
          );
        }
        if (entry.isFile) {
          files[name] = entry;
        }
      }

      final manifestEntry = files[_manifestName];
      final manifestBytes = manifestEntry?.readBytes();
      if (manifestBytes == null || manifestBytes.isEmpty) {
        throw const BackupFormatException(
          'This is not a valid HomeVault backup: manifest.json is missing.',
        );
      }

      final decodedManifest = jsonDecode(utf8.decode(manifestBytes));
      if (decodedManifest is! Map) {
        throw const BackupFormatException(
          'The backup manifest has an invalid format.',
        );
      }
      final manifest = Map<String, dynamic>.from(decodedManifest);
      _validateManifest(manifest);

      return _DecodedBackup(manifest: manifest, files: files);
    } on BackupFormatException {
      rethrow;
    } catch (error) {
      throw BackupFormatException(
        'The selected file is damaged or is not a valid HomeVault backup.',
        error,
      );
    }
  }

  void _validateManifest(Map<String, dynamic> manifest) {
    if (manifest['format'] != backupFormat) {
      throw const BackupFormatException(
        'The selected file is not a HomeVault backup.',
      );
    }

    final schema = _readNonNegativeInt(manifest['schemaVersion']);
    if (schema == 0 || schema > backupSchemaVersion) {
      throw BackupFormatException(
        'This backup uses unsupported schema version $schema.',
      );
    }

    _requiredApplianceData(manifest);
  }

  List<Map<String, dynamic>> _requiredApplianceData(
    Map<String, dynamic> manifest,
  ) {
    final value = manifest['appliances'];
    if (value is! List || value.any((item) => item is! Map)) {
      throw const BackupFormatException(
        'The backup does not contain a valid appliance list.',
      );
    }
    return value
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  int _countMissingArchiveDocuments(
    List<Map<String, dynamic>> appliances,
    Map<String, ArchiveFile> files,
  ) {
    var missing = 0;
    for (final appliance in appliances) {
      for (final document in _documentMaps(appliance)) {
        final archivePath = '${document['localPath'] ?? ''}'.replaceAll(
          '\\',
          '/',
        );
        if (archivePath.isEmpty || files[archivePath] == null) {
          missing++;
        }
      }
    }
    return missing;
  }

  Iterable<Map<String, dynamic>> _documentMaps(Map appliance) sync* {
    final photo = _mapOrNull(appliance['appliancePhotoDocument']);
    if (photo != null) yield photo;
    final invoice = _mapOrNull(appliance['invoiceDocument']);
    if (invoice != null) yield invoice;
    final warranty = _mapOrNull(appliance['warrantyDocument']);
    if (warranty != null) yield warranty;
    final extendedWarranty = _mapOrNull(appliance['extendedWarrantyDocument']);
    if (extendedWarranty != null) yield extendedWarranty;
    final amc = _mapOrNull(appliance['amcDocument']);
    if (amc != null) yield amc;

    final additional = appliance['additionalDocuments'];
    if (additional is List) {
      for (final item in additional.whereType<Map>()) {
        yield Map<String, dynamic>.from(item);
      }
    }

    final services = appliance['serviceRecords'];
    if (services is List) {
      for (final item in services.whereType<Map>()) {
        final receipt = _mapOrNull(item['receiptDocument']);
        if (receipt != null) yield receipt;
        final report = _mapOrNull(item['reportDocument']);
        if (report != null) yield report;
      }
    }
  }

  Future<_RestoredDocumentResult> _restoreDocumentMap(
    Map<String, dynamic>? documentJson, {
    required String applianceId,
    required Map<String, ArchiveFile> decodedFiles,
    required Directory applianceRoot,
    required int restoreStamp,
    required List<String> createdFilePaths,
  }) async {
    if (documentJson == null) {
      return const _RestoredDocumentResult.empty();
    }

    final archivePath = '${documentJson['localPath'] ?? ''}'.replaceAll(
      '\\',
      '/',
    );
    if (!_isSafeArchivePath(archivePath)) {
      return const _RestoredDocumentResult.missing();
    }

    final archiveFile = decodedFiles[archivePath];
    final bytes = archiveFile?.readBytes();
    if (bytes == null) {
      return const _RestoredDocumentResult.missing();
    }

    final typeName = '${documentJson['type'] ?? ''}';
    final documentType = DocumentType.values.firstWhere(
      (type) => type.name == typeName,
      orElse: () => DocumentType.other,
    );
    final fileName = _sanitiseFileName('${documentJson['fileName'] ?? ''}');
    final documentId = _sanitiseFileName('${documentJson['id'] ?? 'document'}');
    final destinationDirectory = Directory(
      path.join(
        applianceRoot.path,
        _sanitisePathPart(applianceId),
        documentType.storageFolder,
      ),
    );
    await destinationDirectory.create(recursive: true);

    var destination = File(
      path.join(
        destinationDirectory.path,
        'restore_${restoreStamp}_${documentId}_$fileName',
      ),
    );
    var suffix = 1;
    while (await destination.exists()) {
      destination = File(
        path.join(
          destinationDirectory.path,
          'restore_${restoreStamp}_${documentId}_${suffix}_$fileName',
        ),
      );
      suffix++;
    }

    await destination.writeAsBytes(bytes, flush: true);
    createdFilePaths.add(destination.path);

    return _RestoredDocumentResult(
      documentJson: <String, dynamic>{
        ...documentJson,
        'localPath': destination.path,
        'sizeBytes': bytes.length,
      },
      restoredCount: 1,
      missingCount: 0,
    );
  }

  bool _isSafeArchivePath(String value) {
    if (value.trim().isEmpty || value.startsWith('/')) {
      return false;
    }
    final parts = value.replaceAll('\\', '/').split('/');
    return !parts.any((part) => part == '..' || part.isEmpty);
  }

  int _readNonNegativeInt(Object? value) {
    final parsed = value is int ? value : int.tryParse('$value');
    return parsed == null || parsed < 0 ? 0 : parsed;
  }

  Map<String, dynamic>? _mapOrNull(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Map<String, dynamic> _deepJsonCopy(Map<String, dynamic> value) {
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  }

  String? _serialKey(Appliance appliance) {
    final serial = appliance.serialNumber.trim().toLowerCase();
    if (serial.isEmpty) {
      return null;
    }
    return '${appliance.brand.trim().toLowerCase()}|$serial';
  }

  String? _serialKeyFromJson(Map<String, dynamic> appliance) {
    final serial = '${appliance['serialNumber'] ?? ''}'.trim().toLowerCase();
    if (serial.isEmpty) {
      return null;
    }
    final brand = '${appliance['brand'] ?? ''}'.trim().toLowerCase();
    return '$brand|$serial';
  }

  Directory _applianceDocumentRoot(
    Directory documentsDirectory,
    String? ownerUid,
  ) {
    final normalized = ownerUid?.trim();
    if (normalized == null || normalized.isEmpty) {
      return Directory(
        path.join(documentsDirectory.path, 'homevault', 'appliances'),
      );
    }

    return Directory(
      path.join(
        documentsDirectory.path,
        'homevault',
        'accounts',
        securityScopeKey(normalized),
        'appliances',
      ),
    );
  }

  Future<bool> _ownsLegacyDocumentRoot(
    Directory documentsDirectory,
    String? ownerUid,
  ) async {
    final normalized = ownerUid?.trim();
    if (normalized == null || normalized.isEmpty) return false;

    final marker = File(
      path.join(
        documentsDirectory.path,
        'homevault',
        'appliances',
        _legacyOwnerMarkerName,
      ),
    );
    if (!await marker.exists()) return false;
    return (await marker.readAsString()).trim() == securityScopeKey(normalized);
  }

  String _backupFileName() {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    return 'HomeVault_Backup_${date}_$time.zip';
  }

  String _sanitiseFileName(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'document' : safe;
  }

  String _sanitisePathPart(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return safe.isEmpty ? 'appliance' : safe;
  }
}

class _BackupBuildState {
  _BackupBuildState(this.archive);

  final Archive archive;
  final Set<String> _usedPaths = {};
  final List<Map<String, dynamic>> missingDocuments = [];
  int documentCount = 0;

  String uniqueArchivePath({
    required String applianceId,
    required String documentId,
    required String fileName,
  }) {
    final safeAppliance = _safePart(applianceId, fallback: 'appliance');
    final safeDocument = _safePart(documentId, fallback: 'document');
    final safeFile = _safePart(fileName, fallback: 'document');
    var candidate = 'documents/$safeAppliance/${safeDocument}_$safeFile';
    var suffix = 1;
    while (!_usedPaths.add(candidate)) {
      candidate =
          'documents/$safeAppliance/${safeDocument}_${suffix}_$safeFile';
      suffix++;
    }
    return candidate;
  }

  String _safePart(String value, {required String fallback}) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? fallback : safe;
  }
}

class _DecodedBackup {
  const _DecodedBackup({required this.manifest, required this.files});

  final Map<String, dynamic> manifest;
  final Map<String, ArchiveFile> files;
}

class _RestoredDocumentResult {
  const _RestoredDocumentResult({
    required this.documentJson,
    required this.restoredCount,
    required this.missingCount,
  });

  const _RestoredDocumentResult.empty()
    : documentJson = null,
      restoredCount = 0,
      missingCount = 0;

  const _RestoredDocumentResult.missing()
    : documentJson = null,
      restoredCount = 0,
      missingCount = 1;

  final Map<String, dynamic>? documentJson;
  final int restoredCount;
  final int missingCount;
}
