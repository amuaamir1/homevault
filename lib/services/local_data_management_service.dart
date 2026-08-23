import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/stored_document.dart';
import '../security/security_scope_key.dart';

class LocalStorageSummary {
  const LocalStorageSummary({
    required this.cloudBackedDocumentCount,
    required this.cloudBackedDocumentBytes,
    required this.localOnlyDocumentCount,
    required this.localOnlyDocumentBytes,
    required this.safetyBackupCount,
    required this.safetyBackupBytes,
  });

  final int cloudBackedDocumentCount;
  final int cloudBackedDocumentBytes;
  final int localOnlyDocumentCount;
  final int localOnlyDocumentBytes;
  final int safetyBackupCount;
  final int safetyBackupBytes;

  int get totalManagedBytes =>
      cloudBackedDocumentBytes + localOnlyDocumentBytes + safetyBackupBytes;

  bool get hasRecoverableLocalCopies => cloudBackedDocumentCount > 0;
  bool get hasSafetyBackups => safetyBackupCount > 0;
}

class LocalCleanupResult {
  const LocalCleanupResult({
    required this.itemCount,
    required this.bytesFreed,
    this.failedItems = 0,
  });

  final int itemCount;
  final int bytesFreed;
  final int failedItems;
}

class LocalDataManagementService {
  LocalDataManagementService({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectoryProvider;

  Future<LocalStorageSummary> summarize({
    required Iterable<StoredDocument> documents,
    required String ownerUid,
  }) async {
    final seenPaths = <String>{};
    var cloudBackedCount = 0;
    var cloudBackedBytes = 0;
    var localOnlyCount = 0;
    var localOnlyBytes = 0;

    for (final document in documents) {
      final localPath = document.localPath.trim();
      if (localPath.isEmpty) continue;

      final normalizedPath = path.normalize(File(localPath).absolute.path);
      if (!seenPaths.add(normalizedPath)) continue;

      final file = File(localPath);
      if (!await file.exists()) continue;

      int size;
      try {
        size = await file.length();
      } catch (_) {
        size = document.sizeBytes < 0 ? 0 : document.sizeBytes;
      }

      if (document.isAvailableInCloud) {
        cloudBackedCount++;
        cloudBackedBytes += size;
      } else {
        localOnlyCount++;
        localOnlyBytes += size;
      }
    }

    final safety = await _safetyBackupFiles(ownerUid);
    var safetyBytes = 0;
    for (final file in safety) {
      try {
        safetyBytes += await file.length();
      } catch (_) {
        // A file removed between listing and sizing is simply ignored.
      }
    }

    return LocalStorageSummary(
      cloudBackedDocumentCount: cloudBackedCount,
      cloudBackedDocumentBytes: cloudBackedBytes,
      localOnlyDocumentCount: localOnlyCount,
      localOnlyDocumentBytes: localOnlyBytes,
      safetyBackupCount: safety.length,
      safetyBackupBytes: safetyBytes,
    );
  }

  Future<LocalCleanupResult> clearSafetyBackups(String ownerUid) async {
    final files = await _safetyBackupFiles(ownerUid);
    var deleted = 0;
    var bytesFreed = 0;
    var failed = 0;

    for (final file in files) {
      var size = 0;
      try {
        size = await file.length();
      } catch (_) {
        // Continue with deletion even if the size cannot be read.
      }

      try {
        if (await file.exists()) await file.delete();
        deleted++;
        bytesFreed += size;
      } catch (_) {
        failed++;
      }
    }

    final directory = await _safetyBackupDirectory(ownerUid);
    try {
      if (await directory.exists() && await directory.list().isEmpty) {
        await directory.delete();
      }
    } catch (_) {
      // Empty-directory cleanup is optional.
    }

    return LocalCleanupResult(
      itemCount: deleted,
      bytesFreed: bytesFreed,
      failedItems: failed,
    );
  }

  Future<List<File>> _safetyBackupFiles(String ownerUid) async {
    final normalizedUid = ownerUid.trim();
    if (normalizedUid.isEmpty) return const <File>[];

    final directory = await _safetyBackupDirectory(normalizedUid);
    if (!await directory.exists()) return const <File>[];

    final files = <File>[];
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.zip')) {
        files.add(entity);
      }
    }
    return files;
  }

  Future<Directory> _safetyBackupDirectory(String ownerUid) async {
    final documentsDirectory = await _documentsDirectoryProvider();
    return Directory(
      path.join(
        documentsDirectory.path,
        'homevault',
        'safety_backups',
        securityScopeKey(ownerUid),
      ),
    );
  }
}

String formatManagedBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';

  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';

  final megabytes = kilobytes / 1024;
  if (megabytes < 1024) return '${megabytes.toStringAsFixed(1)} MB';

  final gigabytes = megabytes / 1024;
  return '${gigabytes.toStringAsFixed(2)} GB';
}
