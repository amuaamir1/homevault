enum DocumentType {
  appliancePhoto,
  invoice,
  warrantyCard,
  extendedWarranty,
  amcContract,
  userManual,
  serviceReceipt,
  serviceReport,
  installationReport,
  other,
}

extension DocumentTypeDetails on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.appliancePhoto:
        return 'Appliance photo';
      case DocumentType.invoice:
        return 'Invoice';
      case DocumentType.warrantyCard:
        return 'Warranty card';
      case DocumentType.extendedWarranty:
        return 'Extended warranty';
      case DocumentType.amcContract:
        return 'AMC contract';
      case DocumentType.userManual:
        return 'User manual';
      case DocumentType.serviceReceipt:
        return 'Service receipt';
      case DocumentType.serviceReport:
        return 'Service report';
      case DocumentType.installationReport:
        return 'Installation report';
      case DocumentType.other:
        return 'Other document';
    }
  }

  String get storageFolder {
    switch (this) {
      case DocumentType.appliancePhoto:
        return 'photos';
      case DocumentType.invoice:
        return 'invoices';
      case DocumentType.warrantyCard:
        return 'warranty';
      case DocumentType.extendedWarranty:
        return 'extended_warranty';
      case DocumentType.amcContract:
        return 'amc';
      case DocumentType.userManual:
        return 'manuals';
      case DocumentType.serviceReceipt:
        return 'service_receipts';
      case DocumentType.serviceReport:
        return 'service_reports';
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
    this.cloudStoragePath = '',
    this.cloudContentType = '',
  }) : id = _resolveId(id, attachedAt, fileName);

  factory StoredDocument.fromJson(Map<String, dynamic> json) {
    final localPath = json['localPath'] as String? ?? '';
    final attachedAt =
        DateTime.tryParse(json['attachedAt'] as String? ?? '') ??
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
      cloudStoragePath: json['cloudStoragePath'] as String? ?? '',
      cloudContentType: json['cloudContentType'] as String? ?? '',
    );
  }

  final String id;
  final DocumentType type;
  final String title;
  final String reference;
  final String notes;
  final String fileName;

  /// Physical file location on this device only.
  final String localPath;

  final int sizeBytes;
  final DateTime attachedAt;

  /// Private Firebase Storage object path. This is safe to synchronize through
  /// Firestore because access is still controlled by Firebase Authentication
  /// and Storage Security Rules.
  final String cloudStoragePath;

  /// MIME type used for the Firebase Storage object.
  final String cloudContentType;

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
    String? cloudStoragePath,
    String? cloudContentType,
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
      cloudStoragePath: cloudStoragePath ?? this.cloudStoragePath,
      cloudContentType: cloudContentType ?? this.cloudContentType,
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
      'cloudStoragePath': cloudStoragePath,
      'cloudContentType': cloudContentType,
    };
  }

  String get displayTitle => title.trim().isEmpty ? type.label : title.trim();

  /// True when this device has a local copy of the attachment.
  bool get isAvailableOnDevice => localPath.trim().isNotEmpty;

  /// True when an authenticated HomeVault device can retrieve the file from
  /// Firebase Storage.
  bool get isAvailableInCloud => cloudStoragePath.trim().isNotEmpty;

  /// A local-only file should be uploaded when cloud document storage is
  /// available. Existing Phase 1C attachments naturally migrate through this
  /// state.
  bool get needsCloudUpload => isAvailableOnDevice && !isAvailableInCloud;

  /// Metadata safe to store in Firestore. The device-only local path is never
  /// uploaded because that path is meaningless on another phone.
  Map<String, dynamic> toCloudMetadataJson() {
    return {...toJson(), 'localPath': ''};
  }

  /// Keeps cloud metadata authoritative while restoring this device's local
  /// path when it already has the same document file.
  StoredDocument withLocalAvailabilityFrom(StoredDocument? localDocument) {
    if (localDocument != null &&
        localDocument.id == id &&
        localDocument.isAvailableOnDevice) {
      final cloudPath = cloudStoragePath.trim();
      final localCloudPath = localDocument.cloudStoragePath.trim();
      final sameCloudObject =
          cloudPath.isEmpty ||
          localCloudPath.isEmpty ||
          cloudPath == localCloudPath;

      if (sameCloudObject) {
        return copyWith(localPath: localDocument.localPath);
      }
    }
    return copyWith(localPath: '');
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

  static String _resolveId(String? id, DateTime attachedAt, String fileName) {
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
