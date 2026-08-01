import 'stored_document.dart';

enum WarrantyStatus { active, expiringSoon, expired, notProvided }

enum WarrantyClaimStatus {
  none,
  submitted,
  inReview,
  approved,
  rejected,
  resolved,
}

extension WarrantyClaimStatusLabel on WarrantyClaimStatus {
  String get label => switch (this) {
    WarrantyClaimStatus.none => 'No claim',
    WarrantyClaimStatus.submitted => 'Submitted',
    WarrantyClaimStatus.inReview => 'In review',
    WarrantyClaimStatus.approved => 'Approved',
    WarrantyClaimStatus.rejected => 'Rejected',
    WarrantyClaimStatus.resolved => 'Resolved',
  };
}

class Appliance {
  Appliance({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.createdAt,
    this.modelNumber = '',
    this.serialNumber = '',
    this.purchaseDate,
    this.warrantyExpiryDate,
    this.supportProvider = '',
    this.supportPhone = '',
    this.supportEmail = '',
    this.supportWebsite = '',
    this.supportNotes = '',
    this.invoiceReference = '',
    this.warrantyProvider = '',
    this.warrantyReference = '',
    this.warrantyTerms = '',
    this.warrantyCoverageNotes = '',
    this.extendedWarrantyProvider = '',
    this.extendedWarrantyReference = '',
    this.extendedWarrantyExpiryDate,
    this.warrantyClaimNumber = '',
    this.warrantyClaimStatus = WarrantyClaimStatus.none,
    this.warrantyMarkedExpired = false,
    this.warrantyReminderEnabled = false,
    this.warrantyReminderDaysBefore = 30,
    this.invoiceDocument,
    this.warrantyDocument,
    List<StoredDocument> additionalDocuments = const [],
    this.notes = '',
  }) : additionalDocuments = List.unmodifiable(additionalDocuments);

  factory Appliance.fromJson(Map<String, dynamic> json) {
    final invoiceDocument = _upgradeLegacyDocument(
      _documentFromJson(json['invoiceDocument']),
      type: DocumentType.invoice,
      fallbackTitle: 'Invoice',
    );
    final warrantyDocument = _upgradeLegacyDocument(
      _documentFromJson(json['warrantyDocument']),
      type: DocumentType.warrantyCard,
      fallbackTitle: 'Warranty card',
    );
    final additionalJson = json['additionalDocuments'];

    return Appliance(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'Other',
      brand: json['brand'] as String? ?? '',
      modelNumber: json['modelNumber'] as String? ?? '',
      serialNumber: json['serialNumber'] as String? ?? '',
      purchaseDate: _dateFromJson(json['purchaseDate']),
      warrantyExpiryDate: _dateFromJson(json['warrantyExpiryDate']),
      supportProvider: json['supportProvider'] as String? ?? '',
      supportPhone: json['supportPhone'] as String? ?? '',
      supportEmail: json['supportEmail'] as String? ?? '',
      supportWebsite: json['supportWebsite'] as String? ?? '',
      supportNotes: json['supportNotes'] as String? ?? '',
      invoiceReference: json['invoiceReference'] as String? ?? '',
      warrantyProvider: json['warrantyProvider'] as String? ?? '',
      warrantyReference: json['warrantyReference'] as String? ?? '',
      warrantyTerms: json['warrantyTerms'] as String? ?? '',
      warrantyCoverageNotes: json['warrantyCoverageNotes'] as String? ?? '',
      extendedWarrantyProvider:
          json['extendedWarrantyProvider'] as String? ?? '',
      extendedWarrantyReference:
          json['extendedWarrantyReference'] as String? ?? '',
      extendedWarrantyExpiryDate: _dateFromJson(
        json['extendedWarrantyExpiryDate'],
      ),
      warrantyClaimNumber: json['warrantyClaimNumber'] as String? ?? '',
      warrantyClaimStatus: _claimStatusFromJson(json['warrantyClaimStatus']),
      warrantyMarkedExpired: json['warrantyMarkedExpired'] as bool? ?? false,
      warrantyReminderEnabled:
          json['warrantyReminderEnabled'] as bool? ?? false,
      warrantyReminderDaysBefore: _reminderDaysFromJson(
        json['warrantyReminderDaysBefore'],
      ),
      invoiceDocument: invoiceDocument,
      warrantyDocument: warrantyDocument,
      additionalDocuments: additionalJson is List
          ? additionalJson
                .whereType<Map>()
                .map(
                  (item) =>
                      StoredDocument.fromJson(Map<String, dynamic>.from(item)),
                )
                .where((document) => document.localPath.isNotEmpty)
                .toList(growable: false)
          : const [],
      notes: json['notes'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String name;
  final String category;
  final String brand;
  final String modelNumber;
  final String serialNumber;
  final DateTime? purchaseDate;
  final DateTime? warrantyExpiryDate;
  final String supportProvider;
  final String supportPhone;
  final String supportEmail;
  final String supportWebsite;
  final String supportNotes;
  final String invoiceReference;
  final String warrantyProvider;
  final String warrantyReference;
  final String warrantyTerms;
  final String warrantyCoverageNotes;
  final String extendedWarrantyProvider;
  final String extendedWarrantyReference;
  final DateTime? extendedWarrantyExpiryDate;
  final String warrantyClaimNumber;
  final WarrantyClaimStatus warrantyClaimStatus;
  final bool warrantyMarkedExpired;
  final bool warrantyReminderEnabled;
  final int warrantyReminderDaysBefore;
  final StoredDocument? invoiceDocument;
  final StoredDocument? warrantyDocument;
  final List<StoredDocument> additionalDocuments;
  final String notes;
  final DateTime createdAt;

  List<StoredDocument> get allDocuments => List.unmodifiable([
    ?invoiceDocument,
    ?warrantyDocument,
    ...additionalDocuments,
  ]);

  int get documentCount => allDocuments.length;

  DateTime? get effectiveWarrantyExpiryDate {
    final standard = warrantyExpiryDate;
    final extended = extendedWarrantyExpiryDate;
    if (standard == null) return extended;
    if (extended == null) return standard;
    return extended.isAfter(standard) ? extended : standard;
  }

  bool get hasExtendedWarranty =>
      extendedWarrantyExpiryDate != null ||
      extendedWarrantyProvider.trim().isNotEmpty ||
      extendedWarrantyReference.trim().isNotEmpty;

  int? warrantyDaysRemainingAt(DateTime now) {
    final expiryDate = effectiveWarrantyExpiryDate;
    if (expiryDate == null) return null;

    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiry.difference(today).inDays;
  }

  DateTime? warrantyReminderDateAt({int hour = 9}) {
    final expiryDate = effectiveWarrantyExpiryDate;
    if (warrantyMarkedExpired ||
        !warrantyReminderEnabled ||
        expiryDate == null) {
      return null;
    }

    return DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
      hour,
    ).subtract(Duration(days: warrantyReminderDaysBefore));
  }

  Appliance withAdditionalDocument(StoredDocument document) {
    return _rebuild(additionalDocuments: [...additionalDocuments, document]);
  }

  Appliance replaceDocument(String documentId, StoredDocument replacement) {
    if (invoiceDocument?.id == documentId) {
      return _rebuild(
        invoiceDocument: replacement.copyWith(type: DocumentType.invoice),
        setInvoiceDocument: true,
      );
    }
    if (warrantyDocument?.id == documentId) {
      return _rebuild(
        warrantyDocument: replacement.copyWith(type: DocumentType.warrantyCard),
        setWarrantyDocument: true,
      );
    }

    final index = additionalDocuments.indexWhere(
      (document) => document.id == documentId,
    );
    if (index == -1) {
      throw StateError('The document could not be found.');
    }

    final updatedDocuments = [...additionalDocuments];
    updatedDocuments[index] = replacement;
    return _rebuild(additionalDocuments: updatedDocuments);
  }

  Appliance withoutDocument(String documentId) {
    return _rebuild(
      invoiceDocument: invoiceDocument?.id == documentId
          ? null
          : invoiceDocument,
      setInvoiceDocument: invoiceDocument?.id == documentId,
      warrantyDocument: warrantyDocument?.id == documentId
          ? null
          : warrantyDocument,
      setWarrantyDocument: warrantyDocument?.id == documentId,
      additionalDocuments: additionalDocuments
          .where((document) => document.id != documentId)
          .toList(growable: false),
    );
  }

  Appliance _rebuild({
    StoredDocument? invoiceDocument,
    bool setInvoiceDocument = false,
    StoredDocument? warrantyDocument,
    bool setWarrantyDocument = false,
    List<StoredDocument>? additionalDocuments,
  }) {
    return Appliance(
      id: id,
      name: name,
      category: category,
      brand: brand,
      modelNumber: modelNumber,
      serialNumber: serialNumber,
      purchaseDate: purchaseDate,
      warrantyExpiryDate: warrantyExpiryDate,
      supportProvider: supportProvider,
      supportPhone: supportPhone,
      supportEmail: supportEmail,
      supportWebsite: supportWebsite,
      supportNotes: supportNotes,
      invoiceReference: invoiceReference,
      warrantyProvider: warrantyProvider,
      warrantyReference: warrantyReference,
      warrantyTerms: warrantyTerms,
      warrantyCoverageNotes: warrantyCoverageNotes,
      extendedWarrantyProvider: extendedWarrantyProvider,
      extendedWarrantyReference: extendedWarrantyReference,
      extendedWarrantyExpiryDate: extendedWarrantyExpiryDate,
      warrantyClaimNumber: warrantyClaimNumber,
      warrantyClaimStatus: warrantyClaimStatus,
      warrantyMarkedExpired: warrantyMarkedExpired,
      warrantyReminderEnabled: warrantyReminderEnabled,
      warrantyReminderDaysBefore: warrantyReminderDaysBefore,
      invoiceDocument: setInvoiceDocument
          ? invoiceDocument
          : this.invoiceDocument,
      warrantyDocument: setWarrantyDocument
          ? warrantyDocument
          : this.warrantyDocument,
      additionalDocuments: additionalDocuments ?? this.additionalDocuments,
      notes: notes,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'brand': brand,
      'modelNumber': modelNumber,
      'serialNumber': serialNumber,
      'purchaseDate': purchaseDate?.toIso8601String(),
      'warrantyExpiryDate': warrantyExpiryDate?.toIso8601String(),
      'supportProvider': supportProvider,
      'supportPhone': supportPhone,
      'supportEmail': supportEmail,
      'supportWebsite': supportWebsite,
      'supportNotes': supportNotes,
      'invoiceReference': invoiceReference,
      'warrantyProvider': warrantyProvider,
      'warrantyReference': warrantyReference,
      'warrantyTerms': warrantyTerms,
      'warrantyCoverageNotes': warrantyCoverageNotes,
      'extendedWarrantyProvider': extendedWarrantyProvider,
      'extendedWarrantyReference': extendedWarrantyReference,
      'extendedWarrantyExpiryDate': extendedWarrantyExpiryDate
          ?.toIso8601String(),
      'warrantyClaimNumber': warrantyClaimNumber,
      'warrantyClaimStatus': warrantyClaimStatus.name,
      'warrantyMarkedExpired': warrantyMarkedExpired,
      'warrantyReminderEnabled': warrantyReminderEnabled,
      'warrantyReminderDaysBefore': warrantyReminderDaysBefore,
      'invoiceDocument': invoiceDocument?.toJson(),
      'warrantyDocument': warrantyDocument?.toJson(),
      'additionalDocuments': additionalDocuments
          .map((document) => document.toJson())
          .toList(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static DateTime? _dateFromJson(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static StoredDocument? _documentFromJson(Object? value) {
    if (value is Map<String, dynamic>) {
      return StoredDocument.fromJson(value);
    }
    if (value is Map) {
      return StoredDocument.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }

  static StoredDocument? _upgradeLegacyDocument(
    StoredDocument? document, {
    required DocumentType type,
    required String fallbackTitle,
  }) {
    if (document == null) {
      return null;
    }

    return document.copyWith(
      type: type,
      title: document.title.trim().isEmpty ? fallbackTitle : document.title,
    );
  }

  static WarrantyClaimStatus _claimStatusFromJson(Object? value) {
    final name = value as String?;
    return WarrantyClaimStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => WarrantyClaimStatus.none,
    );
  }

  static int _reminderDaysFromJson(Object? value) {
    final days = value is int ? value : int.tryParse('$value');
    if (days == null || days < 0) return 30;
    if (days > 365) return 365;
    return days;
  }

  WarrantyStatus warrantyStatusAt(DateTime now) {
    if (warrantyMarkedExpired) {
      return WarrantyStatus.expired;
    }

    final remainingDays = warrantyDaysRemainingAt(now);
    if (remainingDays == null) {
      return WarrantyStatus.notProvided;
    }
    if (remainingDays < 0) {
      return WarrantyStatus.expired;
    }
    if (remainingDays <= 30) {
      return WarrantyStatus.expiringSoon;
    }
    return WarrantyStatus.active;
  }

  bool get hasSupportDetails =>
      supportProvider.trim().isNotEmpty ||
      supportPhone.trim().isNotEmpty ||
      supportEmail.trim().isNotEmpty ||
      supportWebsite.trim().isNotEmpty ||
      supportNotes.trim().isNotEmpty;

  bool get hasSupportAction =>
      supportPhone.trim().isNotEmpty ||
      supportEmail.trim().isNotEmpty ||
      supportWebsite.trim().isNotEmpty;

  bool get hasDocuments => allDocuments.isNotEmpty;
}
