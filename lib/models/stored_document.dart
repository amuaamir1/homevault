class StoredDocument {
  const StoredDocument({
    required this.fileName,
    required this.localPath,
    required this.sizeBytes,
    required this.attachedAt,
  });

  factory StoredDocument.fromJson(Map<String, dynamic> json) {
    return StoredDocument(
      fileName: json['fileName'] as String? ?? '',
      localPath: json['localPath'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      attachedAt: DateTime.tryParse(json['attachedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String fileName;
  final String localPath;
  final int sizeBytes;
  final DateTime attachedAt;

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'localPath': localPath,
      'sizeBytes': sizeBytes,
      'attachedAt': attachedAt.toIso8601String(),
    };
  }

  String get extension {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  String get formattedSize {
    if (sizeBytes < 1024) {
      return '$sizeBytes B';
    }
    final kilobytes = sizeBytes / 1024;
    if (kilobytes < 1024) {
      return '${kilobytes.toStringAsFixed(1)} KB';
    }
    final megabytes = kilobytes / 1024;
    return '${megabytes.toStringAsFixed(1)} MB';
  }
}
