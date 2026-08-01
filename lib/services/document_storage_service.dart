import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/stored_document.dart';

class DocumentStorageService {
  static const int maximumFileSizeBytes = 15 * 1024 * 1024;
  static const List<String> allowedExtensions = [
    'pdf',
    'jpg',
    'jpeg',
    'png',
  ];

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
    final destinationDirectory = Directory(
      path.join(
        rootDirectory.path,
        'homevault',
        'appliances',
        applianceId,
        documentFolder,
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

  Future<void> deleteApplianceDocuments(String applianceId) async {
    final rootDirectory = await getApplicationDocumentsDirectory();
    final applianceDirectory = Directory(
      path.join(
        rootDirectory.path,
        'homevault',
        'appliances',
        applianceId,
      ),
    );

    if (await applianceDirectory.exists()) {
      await applianceDirectory.delete(recursive: true);
    }
  }

  Future<void> deleteStoredDocument(StoredDocument document) async {
    final file = File(document.localPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _sanitiseFileName(String fileName) {
    final sanitised = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return sanitised.isEmpty ? 'document' : sanitised;
  }
}

class DocumentStorageException implements Exception {
  const DocumentStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}
