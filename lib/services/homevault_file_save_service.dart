import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Small boundary around the platform file-save dialog so export code can be
/// unit-tested without invoking a platform plugin.
abstract class HomeVaultFileSaveAdapter {
  const HomeVaultFileSaveAdapter();

  Future<bool> save({
    required String dialogTitle,
    required String fileName,
    required Uint8List bytes,
    required String extension,
  });
}

class FilePickerHomeVaultFileSaveAdapter extends HomeVaultFileSaveAdapter {
  const FilePickerHomeVaultFileSaveAdapter();

  @override
  Future<bool> save({
    required String dialogTitle,
    required String fileName,
    required Uint8List bytes,
    required String extension,
  }) async {
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: extension.trim().isEmpty ? null : [extension],
      bytes: bytes,
    );
    return savedPath != null;
  }
}
