import 'service_record.dart';
import 'stored_document.dart';

enum WarrantyStatus { active, expiringSoon, expired, notProvided }

enum WarrantyDurationUnit { months, years }

extension WarrantyDurationUnitLabel on WarrantyDurationUnit {
  String get label => switch (this) {
    WarrantyDurationUnit.months => 'Month',
    WarrantyDurationUnit.years => 'Year',
  };

  String labelFor(int value) => switch (this) {
    WarrantyDurationUnit.months => value == 1 ? 'month' : 'months',
    WarrantyDurationUnit.years => value == 1 ? 'year' : 'years',
  };
}

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
    this.appliancePhotoDocument,
    this.purchaseDate,
    this.warrantyExpiryDate,
    this.warrantyDurationValue,
    this.warrantyDurationUnit,
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
    this.extendedWarrantyStartDate,
    this.extendedWarrantyExpiryDate,
    this.extendedWarrantyCost = 0,
    this.extendedWarrantyDocument,
    this.amcProvider = '',
    this.amcReference = '',
    this.amcPhone = '',
    this.amcStartDate,
    this.amcExpiryDate,
    this.amcCost = 0,
    this.amcIncludedServices,
    this.amcUsedServices = 0,
    this.amcReminderEnabled = false,
    this.amcReminderDaysBefore = 30,
    this.amcDocument,
    this.amcNotes = '',
    this.warrantyClaimNumber = '',
    this.warrantyClaimStatus = WarrantyClaimStatus.none,
    this.warrantyMarkedExpired = false,
    this.warrantyReminderEnabled = false,
    this.warrantyReminderDaysBefore = 30,
    this.invoiceDocument,
    this.warrantyDocument,
    List<StoredDocument> additionalDocuments = const [],
    List<ServiceRecord> serviceRecords = const [],
    this.notes = '',
    this.cloudRevision = 0,
    this.cloudUpdatedByDevice = '',
  }) : additionalDocuments = List.unmodifiable(additionalDocuments),
       serviceRecords = List.unmodifiable(serviceRecords);

  factory Appliance.fromJson(Map<String, dynamic> json) {
    final appliancePhotoDocument = _upgradeLegacyDocument(
      _documentFromJson(json['appliancePhotoDocument']),
      type: DocumentType.appliancePhoto,
      fallbackTitle: 'Appliance photo',
    );
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
    final extendedWarrantyDocument = _upgradeLegacyDocument(
      _documentFromJson(json['extendedWarrantyDocument']),
      type: DocumentType.extendedWarranty,
      fallbackTitle: 'Extended warranty',
    );
    final amcDocument = _upgradeLegacyDocument(
      _documentFromJson(json['amcDocument']),
      type: DocumentType.amcContract,
      fallbackTitle: 'AMC contract',
    );
    final additionalJson = json['additionalDocuments'];
    final serviceJson = json['serviceRecords'];

    return Appliance(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'Other',
      brand: json['brand'] as String? ?? '',
      modelNumber: json['modelNumber'] as String? ?? '',
      serialNumber: json['serialNumber'] as String? ?? '',
      appliancePhotoDocument: appliancePhotoDocument,
      purchaseDate: _dateFromJson(json['purchaseDate']),
      warrantyExpiryDate: _dateFromJson(json['warrantyExpiryDate']),
      warrantyDurationValue: _positiveIntFromJson(
        json['warrantyDurationValue'],
      ),
      warrantyDurationUnit: _durationUnitFromJson(json['warrantyDurationUnit']),
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
      extendedWarrantyStartDate: _dateFromJson(
        json['extendedWarrantyStartDate'],
      ),
      extendedWarrantyExpiryDate: _dateFromJson(
        json['extendedWarrantyExpiryDate'],
      ),
      extendedWarrantyCost: (json['extendedWarrantyCost'] as num?)?.toDouble() ?? 0,
      extendedWarrantyDocument: extendedWarrantyDocument,
      amcProvider: json['amcProvider'] as String? ?? '',
      amcReference: json['amcReference'] as String? ?? '',
      amcPhone: json['amcPhone'] as String? ?? '',
      amcStartDate: _dateFromJson(json['amcStartDate']),
      amcExpiryDate: _dateFromJson(json['amcExpiryDate']),
      amcCost: (json['amcCost'] as num?)?.toDouble() ?? 0,
      amcIncludedServices: _positiveIntFromJson(json['amcIncludedServices']),
      amcUsedServices: _nonNegativeIntFromJson(json['amcUsedServices']),
      amcReminderEnabled: json['amcReminderEnabled'] as bool? ?? false,
      amcReminderDaysBefore: _reminderDaysFromJson(
        json['amcReminderDaysBefore'],
      ),
      amcDocument: amcDocument,
      amcNotes: json['amcNotes'] as String? ?? '',
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
                .toList(growable: false)
          : const [],
      serviceRecords: serviceJson is List
          ? serviceJson
                .whereType<Map>()
                .map(
                  (item) =>
                      ServiceRecord.fromJson(Map<String, dynamic>.from(item)),
                )
                .where((record) => record.id.isNotEmpty)
                .toList(growable: false)
          : const [],
      notes: json['notes'] as String? ?? '',
      cloudRevision: (json['cloudRevision'] as num?)?.toInt() ?? 0,
      cloudUpdatedByDevice: json['cloudUpdatedByDevice'] as String? ?? '',
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
  final StoredDocument? appliancePhotoDocument;
  final DateTime? purchaseDate;
  final DateTime? warrantyExpiryDate;
  final int? warrantyDurationValue;
  final WarrantyDurationUnit? warrantyDurationUnit;
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
  final DateTime? extendedWarrantyStartDate;
  final DateTime? extendedWarrantyExpiryDate;
  final double extendedWarrantyCost;
  final StoredDocument? extendedWarrantyDocument;
  final String amcProvider;
  final String amcReference;
  final String amcPhone;
  final DateTime? amcStartDate;
  final DateTime? amcExpiryDate;
  final double amcCost;
  final int? amcIncludedServices;
  final int amcUsedServices;
  final bool amcReminderEnabled;
  final int amcReminderDaysBefore;
  final StoredDocument? amcDocument;
  final String amcNotes;
  final String warrantyClaimNumber;
  final WarrantyClaimStatus warrantyClaimStatus;
  final bool warrantyMarkedExpired;
  final bool warrantyReminderEnabled;
  final int warrantyReminderDaysBefore;
  final StoredDocument? invoiceDocument;
  final StoredDocument? warrantyDocument;
  final List<StoredDocument> additionalDocuments;
  final List<ServiceRecord> serviceRecords;
  final String notes;
  final int cloudRevision;
  final String cloudUpdatedByDevice;
  final DateTime createdAt;

  List<StoredDocument> get allDocuments => List.unmodifiable([
    ?invoiceDocument,
    ?warrantyDocument,
    ?extendedWarrantyDocument,
    ?amcDocument,
    ...additionalDocuments,
    ...serviceRecords.expand((record) => record.documents),
  ]);

  /// Every file associated with this appliance, including the appliance photo.
  /// Use [allDocuments] for the Document Vault so the appliance photo is not
  /// counted as a user document.
  List<StoredDocument> get allAttachments => List.unmodifiable([
    ?appliancePhotoDocument,
    ...allDocuments,
  ]);

  int get documentCount => allDocuments.length;

  int get serviceRecordCount => serviceRecords.length;

  double get totalServiceCost => serviceRecords.fold<double>(
    0,
    (total, record) => total + record.serviceCharge,
  );

  ServiceRecord? get latestCompletedServiceRecord {
    final completed = serviceRecords
        .where((record) => record.status == ServiceStatus.completed)
        .toList();
    if (completed.isEmpty) return null;
    completed.sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
    return completed.first;
  }

  ServiceRecord? get maintenanceScheduleRecord {
    final scheduled = serviceRecords
        .where(
          (record) =>
              record.status != ServiceStatus.cancelled &&
              record.nextServiceDate != null,
        )
        .toList();
    if (scheduled.isEmpty) return null;
    scheduled.sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
    return scheduled.first;
  }

  DateTime? get lastServiceDate => latestCompletedServiceRecord?.serviceDate;

  String get serviceFrequencyLabel =>
      maintenanceScheduleRecord?.serviceFrequencyLabel ?? '';

  DateTime? get nextServiceDate => maintenanceScheduleRecord?.nextServiceDate;

  ServiceRecord? serviceRecordById(String recordId) {
    for (final record in serviceRecords) {
      if (record.id == recordId) return record;
    }
    return null;
  }

  String get warrantyDurationLabel {
    final value = warrantyDurationValue;
    final unit = warrantyDurationUnit;
    if (value == null || unit == null) return '';
    return '$value ${unit.labelFor(value)}';
  }

  DateTime? get calculatedWarrantyExpiryDate {
    final startDate = purchaseDate;
    final value = warrantyDurationValue;
    final unit = warrantyDurationUnit;
    if (startDate == null || value == null || unit == null || value <= 0) {
      return null;
    }

    return calculateWarrantyExpiryDate(
      startDate: startDate,
      durationValue: value,
      durationUnit: unit,
    );
  }

  static DateTime calculateWarrantyExpiryDate({
    required DateTime startDate,
    required int durationValue,
    required WarrantyDurationUnit durationUnit,
  }) {
    if (durationValue <= 0) {
      throw ArgumentError.value(
        durationValue,
        'durationValue',
        'Warranty duration must be greater than zero.',
      );
    }

    final monthsToAdd = switch (durationUnit) {
      WarrantyDurationUnit.months => durationValue,
      WarrantyDurationUnit.years => durationValue * 12,
    };

    final anniversary = _addCalendarMonths(startDate, monthsToAdd);

    // Most warranties are expressed as an inclusive calendar period.
    // For a normal calendar anniversary, the warranty ends the day before
    // the same date in the target month/year (08 Aug 2026 + 2 years =>
    // 07 Aug 2028). If the original day does not exist in the target month
    // (for example 31 Jan + 1 month), use the clamped target date itself.
    if (anniversary.day != startDate.day) {
      return anniversary;
    }

    return anniversary.subtract(const Duration(days: 1));
  }

  DateTime? get effectiveWarrantyExpiryDate {
    final standard = warrantyExpiryDate;
    final extended = extendedWarrantyExpiryDate;
    if (standard == null) return extended;
    if (extended == null) return standard;
    return extended.isAfter(standard) ? extended : standard;
  }

  bool get hasExtendedWarranty =>
      extendedWarrantyStartDate != null ||
      extendedWarrantyExpiryDate != null ||
      extendedWarrantyProvider.trim().isNotEmpty ||
      extendedWarrantyReference.trim().isNotEmpty ||
      extendedWarrantyCost > 0 ||
      extendedWarrantyDocument != null;

  bool get hasAmc =>
      amcStartDate != null ||
      amcExpiryDate != null ||
      amcProvider.trim().isNotEmpty ||
      amcReference.trim().isNotEmpty ||
      amcPhone.trim().isNotEmpty ||
      amcCost > 0 ||
      amcIncludedServices != null ||
      amcUsedServices > 0 ||
      amcDocument != null ||
      amcNotes.trim().isNotEmpty;

  int? get amcRemainingServices {
    final included = amcIncludedServices;
    if (included == null) return null;
    final remaining = included - amcUsedServices;
    return remaining < 0 ? 0 : remaining;
  }

  int? amcDaysRemainingAt(DateTime now) {
    final expiryDate = amcExpiryDate;
    if (expiryDate == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiry.difference(today).inDays;
  }

  DateTime? amcReminderDateAt({int hour = 9}) {
    final expiryDate = amcExpiryDate;
    if (!amcReminderEnabled || expiryDate == null) return null;
    return DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
      hour,
    ).subtract(Duration(days: amcReminderDaysBefore));
  }

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

  Appliance withServiceRecord(ServiceRecord record) {
    return _rebuild(serviceRecords: [...serviceRecords, record]);
  }

  Appliance replaceServiceRecord(ServiceRecord record) {
    final index = serviceRecords.indexWhere((item) => item.id == record.id);
    if (index == -1) {
      throw StateError('The service record could not be found.');
    }

    final updated = [...serviceRecords];
    updated[index] = record;
    return _rebuild(serviceRecords: updated);
  }

  Appliance withoutServiceRecord(String recordId) {
    return _rebuild(
      serviceRecords: serviceRecords
          .where((record) => record.id != recordId)
          .toList(growable: false),
    );
  }

  Appliance withAdditionalDocument(StoredDocument document) {
    return _rebuild(additionalDocuments: [...additionalDocuments, document]);
  }

  Appliance replaceDocument(String documentId, StoredDocument replacement) {
    if (appliancePhotoDocument?.id == documentId) {
      return _rebuild(
        appliancePhotoDocument: replacement.copyWith(
          type: DocumentType.appliancePhoto,
        ),
        setAppliancePhotoDocument: true,
      );
    }
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
    if (extendedWarrantyDocument?.id == documentId) {
      return _rebuild(
        extendedWarrantyDocument: replacement.copyWith(
          type: DocumentType.extendedWarranty,
        ),
        setExtendedWarrantyDocument: true,
      );
    }
    if (amcDocument?.id == documentId) {
      return _rebuild(
        amcDocument: replacement.copyWith(type: DocumentType.amcContract),
        setAmcDocument: true,
      );
    }

    final index = additionalDocuments.indexWhere(
      (document) => document.id == documentId,
    );
    if (index != -1) {
      final updatedDocuments = [...additionalDocuments];
      updatedDocuments[index] = replacement;
      return _rebuild(additionalDocuments: updatedDocuments);
    }

    final serviceIndex = serviceRecords.indexWhere(
      (record) => record.documents.any((document) => document.id == documentId),
    );
    if (serviceIndex == -1) {
      throw StateError('The document could not be found.');
    }

    final updatedRecords = [...serviceRecords];
    updatedRecords[serviceIndex] = updatedRecords[serviceIndex].replaceDocument(
      documentId,
      replacement,
    );
    return _rebuild(serviceRecords: updatedRecords);
  }

  Appliance withoutDocument(String documentId) {
    return _rebuild(
      appliancePhotoDocument: appliancePhotoDocument?.id == documentId
          ? null
          : appliancePhotoDocument,
      setAppliancePhotoDocument: appliancePhotoDocument?.id == documentId,
      invoiceDocument: invoiceDocument?.id == documentId
          ? null
          : invoiceDocument,
      setInvoiceDocument: invoiceDocument?.id == documentId,
      warrantyDocument: warrantyDocument?.id == documentId
          ? null
          : warrantyDocument,
      setWarrantyDocument: warrantyDocument?.id == documentId,
      extendedWarrantyDocument: extendedWarrantyDocument?.id == documentId
          ? null
          : extendedWarrantyDocument,
      setExtendedWarrantyDocument:
          extendedWarrantyDocument?.id == documentId,
      amcDocument: amcDocument?.id == documentId ? null : amcDocument,
      setAmcDocument: amcDocument?.id == documentId,
      additionalDocuments: additionalDocuments
          .where((document) => document.id != documentId)
          .toList(growable: false),
      serviceRecords: serviceRecords
          .map((record) => record.withoutDocument(documentId))
          .toList(growable: false),
    );
  }

  Appliance _rebuild({
    StoredDocument? appliancePhotoDocument,
    bool setAppliancePhotoDocument = false,
    StoredDocument? invoiceDocument,
    bool setInvoiceDocument = false,
    StoredDocument? warrantyDocument,
    bool setWarrantyDocument = false,
    StoredDocument? extendedWarrantyDocument,
    bool setExtendedWarrantyDocument = false,
    StoredDocument? amcDocument,
    bool setAmcDocument = false,
    List<StoredDocument>? additionalDocuments,
    List<ServiceRecord>? serviceRecords,
    int? cloudRevision,
    String? cloudUpdatedByDevice,
  }) {
    return Appliance(
      id: id,
      name: name,
      category: category,
      brand: brand,
      modelNumber: modelNumber,
      serialNumber: serialNumber,
      appliancePhotoDocument: setAppliancePhotoDocument
          ? appliancePhotoDocument
          : this.appliancePhotoDocument,
      purchaseDate: purchaseDate,
      warrantyExpiryDate: warrantyExpiryDate,
      warrantyDurationValue: warrantyDurationValue,
      warrantyDurationUnit: warrantyDurationUnit,
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
      extendedWarrantyStartDate: extendedWarrantyStartDate,
      extendedWarrantyExpiryDate: extendedWarrantyExpiryDate,
      extendedWarrantyCost: extendedWarrantyCost,
      extendedWarrantyDocument: setExtendedWarrantyDocument
          ? extendedWarrantyDocument
          : this.extendedWarrantyDocument,
      amcProvider: amcProvider,
      amcReference: amcReference,
      amcPhone: amcPhone,
      amcStartDate: amcStartDate,
      amcExpiryDate: amcExpiryDate,
      amcCost: amcCost,
      amcIncludedServices: amcIncludedServices,
      amcUsedServices: amcUsedServices,
      amcReminderEnabled: amcReminderEnabled,
      amcReminderDaysBefore: amcReminderDaysBefore,
      amcDocument: setAmcDocument ? amcDocument : this.amcDocument,
      amcNotes: amcNotes,
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
      serviceRecords: serviceRecords ?? this.serviceRecords,
      notes: notes,
      cloudRevision: cloudRevision ?? this.cloudRevision,
      cloudUpdatedByDevice: cloudUpdatedByDevice ?? this.cloudUpdatedByDevice,
      createdAt: createdAt,
    );
  }

  Appliance withCloudSyncMetadata({
    required int cloudRevision,
    required String cloudUpdatedByDevice,
  }) {
    return _rebuild(
      cloudRevision: cloudRevision,
      cloudUpdatedByDevice: cloudUpdatedByDevice,
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
      'appliancePhotoDocument': appliancePhotoDocument?.toJson(),
      'purchaseDate': purchaseDate?.toIso8601String(),
      'warrantyExpiryDate': warrantyExpiryDate?.toIso8601String(),
      'warrantyDurationValue': warrantyDurationValue,
      'warrantyDurationUnit': warrantyDurationUnit?.name,
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
      'extendedWarrantyStartDate': extendedWarrantyStartDate?.toIso8601String(),
      'extendedWarrantyExpiryDate': extendedWarrantyExpiryDate
          ?.toIso8601String(),
      'extendedWarrantyCost': extendedWarrantyCost,
      'extendedWarrantyDocument': extendedWarrantyDocument?.toJson(),
      'amcProvider': amcProvider,
      'amcReference': amcReference,
      'amcPhone': amcPhone,
      'amcStartDate': amcStartDate?.toIso8601String(),
      'amcExpiryDate': amcExpiryDate?.toIso8601String(),
      'amcCost': amcCost,
      'amcIncludedServices': amcIncludedServices,
      'amcUsedServices': amcUsedServices,
      'amcReminderEnabled': amcReminderEnabled,
      'amcReminderDaysBefore': amcReminderDaysBefore,
      'amcDocument': amcDocument?.toJson(),
      'amcNotes': amcNotes,
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
      'serviceRecords': serviceRecords
          .map((record) => record.toJson())
          .toList(),
      'notes': notes,
      'cloudRevision': cloudRevision,
      'cloudUpdatedByDevice': cloudUpdatedByDevice,
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

  static int? _positiveIntFromJson(Object? value) {
    final parsed = value is int ? value : int.tryParse('$value');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static int _nonNegativeIntFromJson(Object? value) {
    final parsed = value is int ? value : int.tryParse('$value');
    if (parsed == null || parsed < 0) return 0;
    return parsed;
  }

  static WarrantyDurationUnit? _durationUnitFromJson(Object? value) {
    final name = value as String?;
    if (name == null || name.isEmpty) return null;
    for (final unit in WarrantyDurationUnit.values) {
      if (unit.name == name) return unit;
    }
    return null;
  }

  static DateTime _addCalendarMonths(DateTime date, int months) {
    final monthIndex = date.month - 1 + months;
    final targetYear = date.year + monthIndex ~/ 12;
    final targetMonth = monthIndex % 12 + 1;
    final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final targetDay = date.day <= lastDayOfTargetMonth
        ? date.day
        : lastDayOfTargetMonth;

    return DateTime(
      targetYear,
      targetMonth,
      targetDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
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
