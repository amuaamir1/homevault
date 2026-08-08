import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/stored_document.dart';
import '../security/security_scope_key.dart';

class DocumentStorageService {
  static const int maximumFileSizeBytes = 15 * 1024 * 1024;
  static const List<String> allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];
  static const String _legacyOwnerMarkerName = '.homevault_owner';

  static String? _ownerScope;

  static Future<void> bindOwner(String? uid) async {
    final normalized = uid?.trim();
    _ownerScope = normalized == null || normalized.isEmpty
        ? null
        : securityScopeKey(normalized);
  }

  Future<StoredDocument?> pickAndStore({
    required String applianceId,
    required String documentFolder,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final selectedFile = result.files.single;
    final sourcePath = selectedFile.path;
    if (sourcePath == null || sourcePath.trim().isEmpty) {
      throw const DocumentStorageException(
        'The selected file could not be accessed. Please choose it again.',
      );
    }

    if (selectedFile.size > maximumFileSizeBytes) {
      throw const DocumentStorageException(
        'The selected file is larger than 15 MB.',
      );
    }

    final rootDirectory = await getApplicationDocumentsDirectory();
    await _ensureLegacyOwnership(rootDirectory);
    final destinationDirectory = Directory(
      path.join(
        _accountApplianceRoot(rootDirectory).path,
        _sanitisePathPart(applianceId),
        _sanitisePathPart(documentFolder),
      ),
    );
    await destinationDirectory.create(recursive: true);

    final safeFileName = _sanitiseFileName(selectedFile.name);
    final destinationPath = path.join(
      destinationDirectory.path,
      '${DateTime.now().microsecondsSinceEpoch}_$safeFileName',
    );

    final copiedFile = await File(sourcePath).copy(destinationPath);
    final copiedFileSize = await copiedFile.length();

    return StoredDocument(
      fileName: selectedFile.name,
      localPath: copiedFile.path,
      sizeBytes: copiedFileSize,
      attachedAt: DateTime.now(),
    );
  }

  Future<String> prepareDownloadDestination({
    required String applianceId,
    required StoredDocument document,
  }) async {
    final rootDirectory = await getApplicationDocumentsDirectory();
    await _ensureLegacyOwnership(rootDirectory);

    final destinationDirectory = Directory(
      path.join(
        _accountApplianceRoot(rootDirectory).path,
        _sanitisePathPart(applianceId),
        _sanitisePathPart(document.type.storageFolder),
      ),
    );
    await destinationDirectory.create(recursive: true);

    final safeDocumentId = _sanitisePathPart(document.id);
    final safeFileName = _sanitiseFileName(document.fileName);

    return path.join(
      destinationDirectory.path,
      'cloud_${safeDocumentId}_$safeFileName',
    );
  }

  Future<void> deleteApplianceDocuments(String applianceId) async {
    final rootDirectory = await getApplicationDocumentsDirectory();
    await _ensureLegacyOwnership(rootDirectory);
    final safeApplianceId = _sanitisePathPart(applianceId);
    final accountDirectory = Directory(
      path.join(_accountApplianceRoot(rootDirectory).path, safeApplianceId),
    );

    if (await accountDirectory.exists()) {
      await accountDirectory.delete(recursive: true);
    }

    if (await _currentUserOwnsLegacyDocuments(rootDirectory)) {
      final legacyDirectory = Directory(
        path.join(
          rootDirectory.path,
          'homevault',
          'appliances',
          safeApplianceId,
        ),
      );
      if (await legacyDirectory.exists()) {
        await legacyDirectory.delete(recursive: true);
      }
    }
  }

  Future<void> deleteStoredDocument(StoredDocument document) async {
    if (!document.isAvailableOnDevice) {
      return;
    }

    final file = File(document.localPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Directory _accountApplianceRoot(Directory documentsDirectory) {
    final scope = _ownerScope;
    if (scope == null) {
      throw const DocumentStorageException(
        'Sign in before adding or managing HomeVault documents.',
      );
    }

    return Directory(
      path.join(
        documentsDirectory.path,
        'homevault',
        'accounts',
        scope,
        'appliances',
      ),
    );
  }

  static Future<void> _ensureLegacyOwnership(
    Directory documentsDirectory,
  ) async {
    final scope = _ownerScope;
    if (scope == null) return;

    final legacyRoot = Directory(
      path.join(documentsDirectory.path, 'homevault', 'appliances'),
    );
    if (!await legacyRoot.exists()) return;

    final marker = File(path.join(legacyRoot.path, _legacyOwnerMarkerName));
    if (!await marker.exists()) {
      await marker.writeAsString(scope, flush: true);
    }
  }

  static Future<bool> _currentUserOwnsLegacyDocuments(
    Directory documentsDirectory,
  ) async {
    final scope = _ownerScope;
    if (scope == null) return false;

    final marker = File(
      path.join(
        documentsDirectory.path,
        'homevault',
        'appliances',
        _legacyOwnerMarkerName,
      ),
    );
    if (!await marker.exists()) return false;
    return (await marker.readAsString()).trim() == scope;
  }

  static String _sanitiseFileName(String fileName) {
    final sanitised = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return sanitised.isEmpty ? 'document' : sanitised;
  }

  static String _sanitisePathPart(String value) {
    final sanitised = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return sanitised.isEmpty ? 'item' : sanitised;
  }
}

class DocumentStorageException implements Exception {
  const DocumentStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}
