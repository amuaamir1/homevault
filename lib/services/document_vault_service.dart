import '../models/appliance.dart';
import '../models/stored_document.dart';

enum DocumentVaultCategory {
  purchaseAndWarranty,
  manualsAndInstallation,
  serviceAndMaintenance,
  other,
}

extension DocumentVaultCategoryDetails on DocumentVaultCategory {
  String get label => switch (this) {
    DocumentVaultCategory.purchaseAndWarranty => 'Purchase & warranty',
    DocumentVaultCategory.manualsAndInstallation => 'Manuals & installation',
    DocumentVaultCategory.serviceAndMaintenance => 'Service & maintenance',
    DocumentVaultCategory.other => 'Other',
  };

  bool contains(DocumentType type) => switch (this) {
    DocumentVaultCategory.purchaseAndWarranty =>
      type == DocumentType.invoice ||
          type == DocumentType.warrantyCard ||
          type == DocumentType.extendedWarranty ||
          type == DocumentType.amcContract,
    DocumentVaultCategory.manualsAndInstallation =>
      type == DocumentType.userManual ||
          type == DocumentType.installationReport,
    DocumentVaultCategory.serviceAndMaintenance =>
      type == DocumentType.serviceReceipt || type == DocumentType.serviceReport,
    DocumentVaultCategory.other => type == DocumentType.other,
  };
}

enum DocumentVaultAvailability { all, onDevice, cloudOnly, unavailable }

extension DocumentVaultAvailabilityDetails on DocumentVaultAvailability {
  String get label => switch (this) {
    DocumentVaultAvailability.all => 'Any availability',
    DocumentVaultAvailability.onDevice => 'On this device',
    DocumentVaultAvailability.cloudOnly => 'Cloud only',
    DocumentVaultAvailability.unavailable => 'Unavailable',
  };
}

enum DocumentVaultSort { newest, oldest, title, appliance, type }

extension DocumentVaultSortDetails on DocumentVaultSort {
  String get label => switch (this) {
    DocumentVaultSort.newest => 'Newest first',
    DocumentVaultSort.oldest => 'Oldest first',
    DocumentVaultSort.title => 'Document title',
    DocumentVaultSort.appliance => 'Appliance',
    DocumentVaultSort.type => 'Document type',
  };
}

class DocumentVaultEntry {
  const DocumentVaultEntry({required this.appliance, required this.document});

  final Appliance appliance;
  final StoredDocument document;

  DocumentVaultCategory get category {
    for (final category in DocumentVaultCategory.values) {
      if (category.contains(document.type)) return category;
    }
    return DocumentVaultCategory.other;
  }

  DocumentVaultAvailability get availability {
    if (document.isAvailableOnDevice) {
      return DocumentVaultAvailability.onDevice;
    }
    if (document.isAvailableInCloud) {
      return DocumentVaultAvailability.cloudOnly;
    }
    return DocumentVaultAvailability.unavailable;
  }
}

class DocumentVaultFilter {
  const DocumentVaultFilter({
    this.query = '',
    this.applianceId,
    this.category,
    this.type,
    this.availability = DocumentVaultAvailability.all,
    this.sort = DocumentVaultSort.newest,
  });

  final String query;
  final String? applianceId;
  final DocumentVaultCategory? category;
  final DocumentType? type;
  final DocumentVaultAvailability availability;
  final DocumentVaultSort sort;

  bool get hasFilters =>
      query.trim().isNotEmpty ||
      applianceId != null ||
      category != null ||
      type != null ||
      availability != DocumentVaultAvailability.all ||
      sort != DocumentVaultSort.newest;
}

class DocumentVaultSummary {
  const DocumentVaultSummary({
    required this.totalDocuments,
    required this.appliancesWithDocuments,
    required this.unavailableDocuments,
    required this.cloudOnlyDocuments,
  });

  final int totalDocuments;
  final int appliancesWithDocuments;
  final int unavailableDocuments;
  final int cloudOnlyDocuments;
}

class DocumentVaultService {
  const DocumentVaultService();

  static List<DocumentType> get supportedTypes => DocumentType.values
      .where((type) => type != DocumentType.appliancePhoto)
      .toList(growable: false);

  List<DocumentVaultEntry> entries(Iterable<Appliance> appliances) {
    final result = <DocumentVaultEntry>[];
    for (final appliance in appliances) {
      for (final document in appliance.allDocuments) {
        result.add(
          DocumentVaultEntry(appliance: appliance, document: document),
        );
      }
    }
    return result;
  }

  DocumentVaultSummary summarize(Iterable<DocumentVaultEntry> entries) {
    final snapshot = entries.toList(growable: false);
    return DocumentVaultSummary(
      totalDocuments: snapshot.length,
      appliancesWithDocuments: snapshot
          .map((entry) => entry.appliance.id)
          .toSet()
          .length,
      unavailableDocuments: snapshot
          .where(
            (entry) =>
                entry.availability == DocumentVaultAvailability.unavailable,
          )
          .length,
      cloudOnlyDocuments: snapshot
          .where(
            (entry) =>
                entry.availability == DocumentVaultAvailability.cloudOnly,
          )
          .length,
    );
  }

  List<DocumentVaultEntry> filterAndSort(
    Iterable<DocumentVaultEntry> entries,
    DocumentVaultFilter filter,
  ) {
    final terms = filter.query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);

    final result = entries.where((entry) {
      if (filter.applianceId != null &&
          entry.appliance.id != filter.applianceId) {
        return false;
      }
      if (filter.category != null && entry.category != filter.category) {
        return false;
      }
      if (filter.type != null && entry.document.type != filter.type) {
        return false;
      }
      if (filter.availability != DocumentVaultAvailability.all &&
          entry.availability != filter.availability) {
        return false;
      }
      if (terms.isEmpty) return true;

      final haystack = [
        entry.document.displayTitle,
        entry.document.fileName,
        entry.document.reference,
        entry.document.notes,
        entry.document.type.label,
        entry.category.label,
        entry.appliance.name,
        entry.appliance.category,
        entry.appliance.brand,
        entry.appliance.modelNumber,
        entry.appliance.serialNumber,
      ].join(' ').toLowerCase();

      return terms.every(haystack.contains);
    }).toList();

    switch (filter.sort) {
      case DocumentVaultSort.newest:
        result.sort(
          (a, b) => b.document.attachedAt.compareTo(a.document.attachedAt),
        );
        break;
      case DocumentVaultSort.oldest:
        result.sort(
          (a, b) => a.document.attachedAt.compareTo(b.document.attachedAt),
        );
        break;
      case DocumentVaultSort.title:
        result.sort(
          (a, b) => a.document.displayTitle.toLowerCase().compareTo(
            b.document.displayTitle.toLowerCase(),
          ),
        );
        break;
      case DocumentVaultSort.appliance:
        result.sort((a, b) {
          final appliance = a.appliance.name.toLowerCase().compareTo(
            b.appliance.name.toLowerCase(),
          );
          if (appliance != 0) return appliance;
          return a.document.displayTitle.toLowerCase().compareTo(
            b.document.displayTitle.toLowerCase(),
          );
        });
        break;
      case DocumentVaultSort.type:
        result.sort((a, b) {
          final type = a.document.type.label.toLowerCase().compareTo(
            b.document.type.label.toLowerCase(),
          );
          if (type != 0) return type;
          return a.document.displayTitle.toLowerCase().compareTo(
            b.document.displayTitle.toLowerCase(),
          );
        });
        break;
    }

    return result;
  }
}
