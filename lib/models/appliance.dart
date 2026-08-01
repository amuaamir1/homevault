import 'stored_document.dart';

enum WarrantyStatus {
  active,
  expiringSoon,
  expired,
  notProvided,
}

class Appliance {
  const Appliance({
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
    this.notes = '',
  });

  factory Appliance.fromJson(Map<String, dynamic> json) {
    final invoiceJson = json['invoiceDocument'];
    final warrantyJson = json['warrantyDocument'];

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
      invoiceDocument: invoiceJson is Map<String, dynamic>
          ? StoredDocument.fromJson(invoiceJson)
          : invoiceJson is Map
              ? StoredDocument.fromJson(Map<String, dynamic>.from(invoiceJson))
              : null,
      warrantyDocument: warrantyJson is Map<String, dynamic>
          ? StoredDocument.fromJson(warrantyJson)
          : warrantyJson is Map
              ? StoredDocument.fromJson(Map<String, dynamic>.from(warrantyJson))
              : null,
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
  final String notes;
  final DateTime createdAt;

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

  bool get hasDocuments =>
      invoiceDocument != null || warrantyDocument != null;
}
