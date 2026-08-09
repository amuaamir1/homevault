import 'dart:typed_data';

import 'appliance.dart';

enum RestoreMode { merge, replace }

extension RestoreModeDetails on RestoreMode {
  String get label => switch (this) {
    RestoreMode.merge => 'Merge with current data',
    RestoreMode.replace => 'Replace current data',
  };

  String get description => switch (this) {
    RestoreMode.merge =>
      'Keep the current records and import only appliances that are not already present.',
    RestoreMode.replace =>
      'Replace the current appliance database with the contents of this backup.',
  };
}

class BackupPreview {
  const BackupPreview({
    required this.fileName,
    required this.createdAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.applianceCount,
    required this.documentCount,
    required this.missingDocumentCount,
    this.ownerFingerprint,
  });

  final String fileName;
  final DateTime createdAt;
  final String appVersion;
  final int schemaVersion;
  final int applianceCount;
  final int documentCount;
  final int missingDocumentCount;
  final String? ownerFingerprint;
}

class BackupSelection {
  const BackupSelection({required this.bytes, required this.preview});

  final Uint8List bytes;
  final BackupPreview preview;
}

class BackupArchiveData {
  const BackupArchiveData({
    required this.bytes,
    required this.applianceCount,
    required this.documentCount,
    required this.missingDocuments,
  });

  final Uint8List bytes;
  final int applianceCount;
  final int documentCount;
  final int missingDocuments;
}

class BackupCreationResult {
  const BackupCreationResult({
    required this.fileName,
    required this.applianceCount,
    required this.documentCount,
    required this.missingDocuments,
  });

  final String fileName;
  final int applianceCount;
  final int documentCount;
  final int missingDocuments;
}

class PreparedRestore {
  const PreparedRestore({
    required this.appliances,
    required this.createdFilePaths,
    required this.importedAppliances,
    required this.skippedDuplicates,
    required this.restoredDocuments,
    required this.missingDocuments,
  });

  final List<Appliance> appliances;
  final List<String> createdFilePaths;
  final int importedAppliances;
  final int skippedDuplicates;
  final int restoredDocuments;
  final int missingDocuments;
}

class RestoreResult {
  const RestoreResult({
    required this.mode,
    required this.importedAppliances,
    required this.skippedDuplicates,
    required this.restoredDocuments,
    required this.missingDocuments,
  });

  final RestoreMode mode;
  final int importedAppliances;
  final int skippedDuplicates;
  final int restoredDocuments;
  final int missingDocuments;
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

enum CloudBackupSource { automatic, manual, preRestoreSafety }

extension CloudBackupSourceDetails on CloudBackupSource {
  String get label => switch (this) {
    CloudBackupSource.automatic => 'Automatic',
    CloudBackupSource.manual => 'Manual',
    CloudBackupSource.preRestoreSafety => 'Safety',
  };

  String get storageValue => switch (this) {
    CloudBackupSource.automatic => 'automatic',
    CloudBackupSource.manual => 'manual',
    CloudBackupSource.preRestoreSafety => 'preRestoreSafety',
  };
}

class CloudBackupSnapshot {
  const CloudBackupSnapshot({
    required this.id,
    required this.createdAt,
    required this.source,
    required this.applianceCount,
    required this.documentCount,
    required this.missingDocuments,
    required this.sizeBytes,
    required this.storagePath,
    required this.appVersion,
  });

  final String id;
  final DateTime createdAt;
  final CloudBackupSource source;
  final int applianceCount;
  final int documentCount;
  final int missingDocuments;
  final int sizeBytes;
  final String storagePath;
  final String appVersion;
}
