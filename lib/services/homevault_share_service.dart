import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'homevault_export_service.dart';

enum HomeVaultShareStatus { success, dismissed, unavailable }

class HomeVaultShareResult {
  const HomeVaultShareResult(this.status);

  final HomeVaultShareStatus status;

  bool get shared => status == HomeVaultShareStatus.success;
}

abstract class HomeVaultNativeShareGateway {
  Future<HomeVaultShareResult> shareFile({
    required String filePath,
    required String mimeType,
    required String title,
    required String subject,
  });
}

class SharePlusNativeShareGateway implements HomeVaultNativeShareGateway {
  const SharePlusNativeShareGateway();

  @override
  Future<HomeVaultShareResult> shareFile({
    required String filePath,
    required String mimeType,
    required String title,
    required String subject,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: mimeType)],
        title: title,
        subject: subject,
      ),
    );

    final status = switch (result.status) {
      ShareResultStatus.success => HomeVaultShareStatus.success,
      ShareResultStatus.dismissed => HomeVaultShareStatus.dismissed,
      ShareResultStatus.unavailable => HomeVaultShareStatus.unavailable,
    };
    return HomeVaultShareResult(status);
  }
}

class HomeVaultShareService {
  HomeVaultShareService({
    HomeVaultNativeShareGateway? nativeShareGateway,
    Future<Directory> Function()? temporaryDirectoryProvider,
    DateTime Function()? clock,
    this.staleAfter = const Duration(hours: 24),
  }) : _nativeShareGateway =
           nativeShareGateway ?? const SharePlusNativeShareGateway(),
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _clock = clock ?? DateTime.now;

  static const String shareDirectoryName = 'homevault_share';
  static const Set<String> _allowedMimeTypes = {'text/csv', 'application/pdf'};

  final HomeVaultNativeShareGateway _nativeShareGateway;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final DateTime Function() _clock;
  final Duration staleAfter;

  Future<HomeVaultShareResult> shareArtifact(
    HomeVaultExportArtifact artifact,
  ) async {
    _validateArtifact(artifact);
    await cleanupStaleShareFiles();

    final shareDirectory = await _shareDirectory();
    final safeFileName = _safeFileName(artifact.fileName);
    final shareFile = File(path.join(shareDirectory.path, safeFileName));
    await shareFile.writeAsBytes(artifact.bytes, flush: true);

    return _nativeShareGateway.shareFile(
      filePath: shareFile.path,
      mimeType: artifact.mimeType,
      title: 'Share ${artifact.displayName}',
      subject: 'HomeVault ${artifact.displayName}',
    );
  }

  Future<int> cleanupStaleShareFiles() async {
    final shareDirectory = await _shareDirectory(createIfMissing: false);
    if (!await shareDirectory.exists()) return 0;

    final cutoff = _clock().subtract(staleAfter);
    var deleted = 0;

    await for (final entity in shareDirectory.list(followLinks: false)) {
      if (entity is! File) continue;

      try {
        final modified = await entity.lastModified();
        if (modified.isBefore(cutoff)) {
          await entity.delete();
          deleted++;
        }
      } on FileSystemException {
        // Best-effort cleanup must never block sharing a new HomeVault report.
      }
    }

    return deleted;
  }

  Future<Directory> _shareDirectory({bool createIfMissing = true}) async {
    final temporaryDirectory = await _temporaryDirectoryProvider();
    final directory = Directory(
      path.join(temporaryDirectory.path, shareDirectoryName),
    );
    if (createIfMissing && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  void _validateArtifact(HomeVaultExportArtifact artifact) {
    if (!_allowedMimeTypes.contains(artifact.mimeType)) {
      throw ArgumentError.value(
        artifact.mimeType,
        'artifact.mimeType',
        'P17 Phase 1 only shares HomeVault CSV reports and PDF summaries.',
      );
    }

    final extension = artifact.extension;
    final validExtension =
        (artifact.mimeType == 'text/csv' && extension == 'csv') ||
        (artifact.mimeType == 'application/pdf' && extension == 'pdf');
    if (!validExtension) {
      throw ArgumentError.value(
        artifact.fileName,
        'artifact.fileName',
        'The file extension does not match the report type.',
      );
    }

    if (artifact.bytes.isEmpty) {
      throw ArgumentError.value(
        artifact.fileName,
        'artifact',
        'Cannot share an empty HomeVault report.',
      );
    }
  }

  String _safeFileName(String value) {
    final withoutSeparators = value
        .replaceAll('/', '_')
        .replaceAll(r'\', '_')
        .trim();
    final safe = withoutSeparators.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final collapsed = safe.replaceAll(RegExp(r'_+'), '_');
    final withoutTraversal = collapsed.replaceAll('..', '.');
    final normalized = withoutTraversal.replaceFirst(RegExp(r'^\.+'), '');
    return normalized.isEmpty ? 'HomeVault_Report' : normalized;
  }
}
