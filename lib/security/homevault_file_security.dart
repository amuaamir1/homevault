import 'dart:io';
import 'dart:typed_data';

enum HomeVaultFileKind { pdf, jpeg, png }

class HomeVaultFileSecurity {
  const HomeVaultFileSecurity._();

  static const int headerBytesToRead = 16;

  static String normalizedExtension(String fileName) {
    final name = fileName.trim().toLowerCase();
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1);
  }

  static String? contentTypeForFileName(String fileName) {
    return switch (normalizedExtension(fileName)) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => null,
    };
  }

  static HomeVaultFileKind? kindForFileName(String fileName) {
    return switch (normalizedExtension(fileName)) {
      'pdf' => HomeVaultFileKind.pdf,
      'jpg' || 'jpeg' => HomeVaultFileKind.jpeg,
      'png' => HomeVaultFileKind.png,
      _ => null,
    };
  }

  static Future<String> validateFile(
    File file, {
    required String fileName,
    required int maximumBytes,
    Set<String>? allowedExtensions,
  }) async {
    final size = await file.length();
    if (size <= 0) {
      throw const HomeVaultFileSecurityException('The selected file is empty.');
    }
    if (size > maximumBytes) {
      final limitMb = maximumBytes ~/ (1024 * 1024);
      throw HomeVaultFileSecurityException(
        'The selected file is larger than $limitMb MB.',
      );
    }

    final handle = await file.open();
    try {
      final header = await handle.read(
        size < headerBytesToRead ? size : headerBytesToRead,
      );
      return validateHeader(
        Uint8List.fromList(header),
        fileName: fileName,
        allowedExtensions: allowedExtensions,
      );
    } finally {
      await handle.close();
    }
  }

  static String validateBytes(
    Uint8List bytes, {
    required String fileName,
    required int maximumBytes,
    Set<String>? allowedExtensions,
  }) {
    if (bytes.isEmpty) {
      throw const HomeVaultFileSecurityException('The selected file is empty.');
    }
    if (bytes.length > maximumBytes) {
      final limitMb = maximumBytes ~/ (1024 * 1024);
      throw HomeVaultFileSecurityException(
        'The selected file is larger than $limitMb MB.',
      );
    }

    final length = bytes.length < headerBytesToRead
        ? bytes.length
        : headerBytesToRead;
    return validateHeader(
      Uint8List.sublistView(bytes, 0, length),
      fileName: fileName,
      allowedExtensions: allowedExtensions,
    );
  }

  static String validateHeader(
    Uint8List header, {
    required String fileName,
    Set<String>? allowedExtensions,
  }) {
    final extension = normalizedExtension(fileName);
    if (extension.isEmpty) {
      throw const HomeVaultFileSecurityException(
        'The selected file does not have a supported file extension.',
      );
    }

    if (allowedExtensions != null && !allowedExtensions.contains(extension)) {
      throw const HomeVaultFileSecurityException(
        'Only PDF, JPG, JPEG, and PNG files are supported.',
      );
    }

    final expectedKind = kindForFileName(fileName);
    final contentType = contentTypeForFileName(fileName);
    if (expectedKind == null || contentType == null) {
      throw const HomeVaultFileSecurityException(
        'Only PDF, JPG, JPEG, and PNG files are supported.',
      );
    }

    if (!_matchesSignature(header, expectedKind)) {
      throw const HomeVaultFileSecurityException(
        'The selected file content does not match its file type.',
      );
    }

    return contentType;
  }

  static bool _matchesSignature(
    Uint8List header,
    HomeVaultFileKind expectedKind,
  ) {
    return switch (expectedKind) {
      HomeVaultFileKind.pdf =>
        header.length >= 5 &&
            header[0] == 0x25 &&
            header[1] == 0x50 &&
            header[2] == 0x44 &&
            header[3] == 0x46 &&
            header[4] == 0x2d,
      HomeVaultFileKind.jpeg =>
        header.length >= 3 &&
            header[0] == 0xff &&
            header[1] == 0xd8 &&
            header[2] == 0xff,
      HomeVaultFileKind.png =>
        header.length >= 8 &&
            header[0] == 0x89 &&
            header[1] == 0x50 &&
            header[2] == 0x4e &&
            header[3] == 0x47 &&
            header[4] == 0x0d &&
            header[5] == 0x0a &&
            header[6] == 0x1a &&
            header[7] == 0x0a,
    };
  }
}

class HomeVaultFileSecurityException implements Exception {
  const HomeVaultFileSecurityException(this.message);

  final String message;

  @override
  String toString() => message;
}
