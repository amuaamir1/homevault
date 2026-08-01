enum DocumentType {
  invoice,
  warrantyCard,
  userManual,
  serviceReceipt,
  installationReport,
  other,
}

extension DocumentTypeDetails on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.invoice:
        return 'Invoice';
      case DocumentType.warrantyCard:
        return 'Warranty card';
      case DocumentType.userManual:
        return 'User manual';
      case DocumentType.serviceReceipt:
        return 'Service receipt';
      case DocumentType.installationReport:
        return 'Installation report';
      case DocumentType.other:
        return 'Other document';
    }
  }

  String get storageFolder {
    switch (this) {
      case DocumentType.invoice:
        return 'invoices';
      case DocumentType.warrantyCard:
        return 'warranty';
      case DocumentType.userManual:
        return 'manuals';
      case DocumentType.serviceReceipt:
        return 'service_receipts';
      case DocumentType.installationReport:
        return 'installation_reports';
      case DocumentType.other:
        return 'other';
    }
  }
}

class StoredDocument {
  StoredDocument({
    String? id,
    this.type = DocumentType.other,
    this.title = '',
    this.reference = '',
    this.notes = '',
    required this.fileName,
    required this.localPath,
    required this.sizeBytes,
    required this.attachedAt,
  }) : id = _resolveId(id, attachedAt, fileName);

  factory StoredDocument.fromJson(Map<String, dynamic> json) {
    final localPath = json['localPath'] as String? ?? '';
    final attachedAt = DateTime.tryParse(json['attachedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return StoredDocument(
      id: json['id'] as String? ?? localPath,
      type: _typeFromJson(json['type']),
      title: json['title'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      localPath: localPath,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      attachedAt: attachedAt,
    );
  }

  final String id;
  final DocumentType type;
  final String title;
  final String reference;
  final String notes;
  final String fileName;
  final String localPath;
  final int sizeBytes;
  final DateTime attachedAt;

  StoredDocument copyWith({
    String? id,
    DocumentType? type,
    String? title,
    String? reference,
    String? notes,
    String? fileName,
    String? localPath,
    int? sizeBytes,
    DateTime? attachedAt,
  }) {
    return StoredDocument(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      fileName: fileName ?? this.fileName,
      localPath: localPath ?? this.localPath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      attachedAt: attachedAt ?? this.attachedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'reference': reference,
      'notes': notes,
      'fileName': fileName,
      'localPath': localPath,
      'sizeBytes': sizeBytes,
      'attachedAt': attachedAt.toIso8601String(),
    };
  }

  String get displayTitle => title.trim().isEmpty ? type.label : title.trim();

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

  static String _resolveId(
    String? id,
    DateTime attachedAt,
    String fileName,
  ) {
    if (id != null && id.trim().isNotEmpty) {
      return id;
    }
    return '${attachedAt.microsecondsSinceEpoch}_${fileName.replaceAll(' ', '_')}';
  }

  static DocumentType _typeFromJson(Object? value) {
    if (value is String) {
      for (final type in DocumentType.values) {
        if (type.name == value) {
          return type;
        }
      }
    }
    return DocumentType.other;
  }
}
