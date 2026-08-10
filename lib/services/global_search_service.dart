import '../models/appliance.dart';
import '../models/global_search_result.dart';
import '../models/service_record.dart';
import '../models/stored_document.dart';

class GlobalSearchService {
  const GlobalSearchService();

  List<GlobalSearchResult> search({
    required Iterable<Appliance> appliances,
    required String query,
    GlobalSearchFilter filter = GlobalSearchFilter.all,
  }) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final tokens = normalizedQuery
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    final results = <GlobalSearchResult>[];

    for (final appliance in appliances) {
      if (_allows(filter, GlobalSearchResultType.appliance)) {
        results.add(
          GlobalSearchResult(
            type: GlobalSearchResultType.appliance,
            applianceId: appliance.id,
            title: appliance.name,
            subtitle: _applianceSubtitle(appliance),
            searchText: _join([
              appliance.name,
              appliance.category,
              appliance.brand,
              appliance.modelNumber,
              appliance.serialNumber,
              appliance.amcProvider,
              appliance.amcReference,
              appliance.amcPhone,
              appliance.amcNotes,
              appliance.notes,
            ]),
            sortDate: appliance.createdAt,
          ),
        );
      }

      if (_allows(filter, GlobalSearchResultType.document)) {
        for (final document in appliance.allDocuments) {
          results.add(
            GlobalSearchResult(
              type: GlobalSearchResultType.document,
              applianceId: appliance.id,
              title: document.displayTitle,
              subtitle:
                  '${appliance.name} • ${document.type.label} • ${document.fileName}',
              searchText: _join([
                appliance.name,
                appliance.brand,
                document.displayTitle,
                document.type.label,
                document.reference,
                document.fileName,
                document.notes,
              ]),
              sortDate: document.attachedAt,
            ),
          );
        }
      }

      if (_allows(filter, GlobalSearchResultType.support) &&
          appliance.hasSupportDetails) {
        final provider = appliance.supportProvider.trim().isEmpty
            ? '${appliance.name} support'
            : appliance.supportProvider.trim();
        results.add(
          GlobalSearchResult(
            type: GlobalSearchResultType.support,
            applianceId: appliance.id,
            title: provider,
            subtitle: _supportSubtitle(appliance),
            searchText: _join([
              appliance.name,
              appliance.brand,
              appliance.supportProvider,
              appliance.supportPhone,
              appliance.supportEmail,
              appliance.supportWebsite,
              appliance.supportNotes,
            ]),
            sortDate: appliance.createdAt,
          ),
        );
      }

      if (_allows(filter, GlobalSearchResultType.warranty) &&
          _hasWarrantyData(appliance)) {
        final provider = appliance.extendedWarrantyProvider.trim().isNotEmpty
            ? appliance.extendedWarrantyProvider.trim()
            : appliance.warrantyProvider.trim();
        results.add(
          GlobalSearchResult(
            type: GlobalSearchResultType.warranty,
            applianceId: appliance.id,
            title: '${appliance.name} warranty',
            subtitle: [
              if (provider.isNotEmpty) provider,
              _warrantyStatusLabel(appliance.warrantyStatusAt(DateTime.now())),
              if (appliance.warrantyClaimNumber.trim().isNotEmpty)
                'Claim ${appliance.warrantyClaimNumber.trim()}',
            ].join(' • '),
            searchText: _join([
              appliance.name,
              appliance.brand,
              appliance.warrantyProvider,
              appliance.warrantyReference,
              appliance.warrantyTerms,
              appliance.warrantyCoverageNotes,
              appliance.extendedWarrantyProvider,
              appliance.extendedWarrantyReference,
              appliance.amcProvider,
              appliance.amcReference,
              appliance.amcPhone,
              appliance.amcNotes,
              appliance.warrantyClaimNumber,
              appliance.warrantyClaimStatus.label,
            ]),
            sortDate:
                appliance.effectiveWarrantyExpiryDate ?? appliance.createdAt,
          ),
        );
      }

      if (_allows(filter, GlobalSearchResultType.service)) {
        for (final record in appliance.serviceRecords) {
          results.add(
            GlobalSearchResult(
              type: GlobalSearchResultType.service,
              applianceId: appliance.id,
              title: _serviceTitle(record),
              subtitle: _serviceSubtitle(appliance, record),
              searchText: _join([
                appliance.name,
                appliance.brand,
                record.status.label,
                record.provider,
                record.technicianName,
                record.ticketNumber,
                record.problemDescription,
                record.workCompleted,
                record.partsReplaced,
                record.paymentMethod,
                record.notes,
              ]),
              sortDate: record.serviceDate,
            ),
          );
        }
      }
    }

    final matches = results.where((result) {
      final normalizedText = _normalize(result.searchText);
      return tokens.every(normalizedText.contains);
    }).toList();

    matches.sort((first, second) {
      final firstScore = _score(first, normalizedQuery);
      final secondScore = _score(second, normalizedQuery);
      final scoreComparison = secondScore.compareTo(firstScore);
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      return second.sortDate.compareTo(first.sortDate);
    });

    return List.unmodifiable(matches);
  }

  bool _allows(GlobalSearchFilter filter, GlobalSearchResultType type) {
    if (filter == GlobalSearchFilter.all) {
      return true;
    }

    return switch (filter) {
      GlobalSearchFilter.all => true,
      GlobalSearchFilter.appliances => type == GlobalSearchResultType.appliance,
      GlobalSearchFilter.documents => type == GlobalSearchResultType.document,
      GlobalSearchFilter.support => type == GlobalSearchResultType.support,
      GlobalSearchFilter.warranties => type == GlobalSearchResultType.warranty,
      GlobalSearchFilter.services => type == GlobalSearchResultType.service,
    };
  }

  int _score(GlobalSearchResult result, String normalizedQuery) {
    final title = _normalize(result.title);
    var score = 0;
    if (title == normalizedQuery) {
      score += 100;
    } else if (title.startsWith(normalizedQuery)) {
      score += 60;
    } else if (title.contains(normalizedQuery)) {
      score += 30;
    }

    if (result.type == GlobalSearchResultType.appliance) {
      score += 5;
    }
    return score;
  }

  bool _hasWarrantyData(Appliance appliance) {
    return appliance.effectiveWarrantyExpiryDate != null ||
        appliance.warrantyProvider.trim().isNotEmpty ||
        appliance.warrantyReference.trim().isNotEmpty ||
        appliance.extendedWarrantyProvider.trim().isNotEmpty ||
        appliance.extendedWarrantyReference.trim().isNotEmpty ||
        appliance.warrantyClaimNumber.trim().isNotEmpty ||
        appliance.warrantyTerms.trim().isNotEmpty ||
        appliance.warrantyCoverageNotes.trim().isNotEmpty ||
        appliance.warrantyMarkedExpired;
  }

  String _applianceSubtitle(Appliance appliance) {
    final details = [
      if (appliance.brand.trim().isNotEmpty) appliance.brand.trim(),
      appliance.category,
      if (appliance.modelNumber.trim().isNotEmpty)
        'Model ${appliance.modelNumber.trim()}',
    ];
    return details.join(' • ');
  }

  String _supportSubtitle(Appliance appliance) {
    final details = [
      appliance.name,
      if (appliance.supportPhone.trim().isNotEmpty)
        appliance.supportPhone.trim(),
      if (appliance.supportEmail.trim().isNotEmpty)
        appliance.supportEmail.trim(),
      if (appliance.supportWebsite.trim().isNotEmpty)
        appliance.supportWebsite.trim(),
    ];
    return details.join(' • ');
  }

  String _serviceTitle(ServiceRecord record) {
    final ticket = record.ticketNumber.trim();
    return ticket.isEmpty
        ? '${record.status.label} service'
        : '${record.status.label} • $ticket';
  }

  String _serviceSubtitle(Appliance appliance, ServiceRecord record) {
    final details = [
      appliance.name,
      if (record.provider.trim().isNotEmpty) record.provider.trim(),
      if (record.problemDescription.trim().isNotEmpty)
        record.problemDescription.trim(),
    ];
    return details.join(' • ');
  }

  String _warrantyStatusLabel(WarrantyStatus status) {
    return switch (status) {
      WarrantyStatus.active => 'Active',
      WarrantyStatus.expiringSoon => 'Expiring soon',
      WarrantyStatus.expired => 'Expired',
      WarrantyStatus.notProvided => 'No expiry date',
    };
  }

  String _join(Iterable<String> values) {
    return values.where((value) => value.trim().isNotEmpty).join(' ');
  }

  String _normalize(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
