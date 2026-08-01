import 'stored_document.dart';

enum WarrantyStatus {
  active,
  expiringSoon,
  expired,
  notProvided,
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
    this.supportPhone = '',
    this.supportEmail = '',
    this.supportWebsite = '',
    this.invoiceReference = '',
    this.warrantyProvider = '',
    this.warrantyReference = '',
    this.invoiceDocument,
    this.warrantyDocument,
    List<StoredDocument> additionalDocuments = const [],
    this.notes = '',
  }) : additionalDocuments = List.unmodifiable(additionalDocuments);

  factory Appliance.fromJson(Map<String, dynamic> json) {
    final invoiceJson = json['invoiceDocument'];
    final warrantyJson = json['warrantyDocument'];
    final additionalJson = json['additionalDocuments'];

    final legacyInvoice = _documentFromJson(invoiceJson);
    final legacyWarranty = _documentFromJson(warrantyJson);
    final invoiceDocument = legacyInvoice?.copyWith(
            type: DocumentType.invoice,
            title: legacyInvoice.title.trim().isEmpty
                ? 'Invoice'
                : legacyInvoice.title,
          );
    final warrantyDocument = legacyWarranty?.copyWith(
            type: DocumentType.warrantyCard,
            title: legacyWarranty.title.trim().isEmpty
                ? 'Warranty card'
                : legacyWarranty.title,
          );

    return Appliance(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'Other',
      brand: json['brand'] as String? ?? '',
      modelNumber: json['modelNumber'] as String? ?? '',
      serialNumber: json['serialNumber'] as String? ?? '',
      purchaseDate: _dateFromJson(json['purchaseDate']),
      warrantyExpiryDate: _dateFromJson(json['warrantyExpiryDate']),
      supportPhone: json['supportPhone'] as String? ?? '',
      supportEmail: json['supportEmail'] as String? ?? '',
      supportWebsite: json['supportWebsite'] as String? ?? '',
      invoiceReference: json['invoiceReference'] as String? ?? '',
      warrantyProvider: json['warrantyProvider'] as String? ?? '',
      warrantyReference: json['warrantyReference'] as String? ?? '',
      invoiceDocument: invoiceDocument,
      warrantyDocument: warrantyDocument,
      additionalDocuments: additionalJson is List
          ? additionalJson
              .whereType<Map>()
              .map(
                (item) => StoredDocument.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((document) => document.localPath.isNotEmpty)
              .toList(growable: false)
          : const [],
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
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
  final String supportPhone;
  final String supportEmail;
  final String supportWebsite;
  final String invoiceReference;
  final String warrantyProvider;
  final String warrantyReference;
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

  Appliance withAdditionalDocument(StoredDocument document) {
    return _rebuild(
      additionalDocuments: [...additionalDocuments, document],
    );
  }

  Appliance replaceDocument(
    String documentId,
    StoredDocument replacement,
  ) {
    if (invoiceDocument?.id == documentId) {
      return _rebuild(
        invoiceDocument: replacement.copyWith(type: DocumentType.invoice),
        setInvoiceDocument: true,
      );
    }
    if (warrantyDocument?.id == documentId) {
      return _rebuild(
        warrantyDocument:
            replacement.copyWith(type: DocumentType.warrantyCard),
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
      invoiceDocument:
          invoiceDocument?.id == documentId ? null : invoiceDocument,
      setInvoiceDocument: invoiceDocument?.id == documentId,
      warrantyDocument:
          warrantyDocument?.id == documentId ? null : warrantyDocument,
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
      supportPhone: supportPhone,
      supportEmail: supportEmail,
      supportWebsite: supportWebsite,
      invoiceReference: invoiceReference,
      warrantyProvider: warrantyProvider,
      warrantyReference: warrantyReference,
      invoiceDocument:
          setInvoiceDocument ? invoiceDocument : this.invoiceDocument,
      warrantyDocument:
          setWarrantyDocument ? warrantyDocument : this.warrantyDocument,
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
      'supportPhone': supportPhone,
      'supportEmail': supportEmail,
      'supportWebsite': supportWebsite,
      'invoiceReference': invoiceReference,
      'warrantyProvider': warrantyProvider,
      'warrantyReference': warrantyReference,
      'invoiceDocument': invoiceDocument?.toJson(),
      'warrantyDocument': warrantyDocument?.toJson(),
      'additionalDocuments':
          additionalDocuments.map((document) => document.toJson()).toList(),
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

  WarrantyStatus warrantyStatusAt(DateTime now) {
    final expiryDate = warrantyExpiryDate;
    if (expiryDate == null) {
      return WarrantyStatus.notProvided;
    }

    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final remainingDays = expiry.difference(today).inDays;

    if (remainingDays < 0) {
      return WarrantyStatus.expired;
    }
    if (remainingDays <= 30) {
      return WarrantyStatus.expiringSoon;
    }
    return WarrantyStatus.active;
  }

  bool get hasSupportDetails =>
      supportPhone.trim().isNotEmpty ||
      supportEmail.trim().isNotEmpty ||
      supportWebsite.trim().isNotEmpty;

  bool get hasDocuments => allDocuments.isNotEmpty;
}
