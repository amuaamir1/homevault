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

  Appliance copyWith({
    String? id,
    String? name,
    String? category,
    String? brand,
    String? modelNumber,
    String? serialNumber,
    DateTime? purchaseDate,
    DateTime? warrantyExpiryDate,
    String? supportPhone,
    String? supportEmail,
    String? supportWebsite,
    String? invoiceReference,
    String? warrantyProvider,
    String? warrantyReference,
    StoredDocument? invoiceDocument,
    StoredDocument? warrantyDocument,
    String? notes,
    DateTime? createdAt,
  }) {
    return Appliance(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      modelNumber: modelNumber ?? this.modelNumber,
      serialNumber: serialNumber ?? this.serialNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      warrantyExpiryDate: warrantyExpiryDate ?? this.warrantyExpiryDate,
      supportPhone: supportPhone ?? this.supportPhone,
      supportEmail: supportEmail ?? this.supportEmail,
      supportWebsite: supportWebsite ?? this.supportWebsite,
      invoiceReference: invoiceReference ?? this.invoiceReference,
      warrantyProvider: warrantyProvider ?? this.warrantyProvider,
      warrantyReference: warrantyReference ?? this.warrantyReference,
      invoiceDocument: invoiceDocument ?? this.invoiceDocument,
      warrantyDocument: warrantyDocument ?? this.warrantyDocument,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
