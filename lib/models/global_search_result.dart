enum GlobalSearchFilter {
  all,
  appliances,
  documents,
  support,
  warranties,
  services,
}

extension GlobalSearchFilterDetails on GlobalSearchFilter {
  String get label => switch (this) {
    GlobalSearchFilter.all => 'All',
    GlobalSearchFilter.appliances => 'Appliances',
    GlobalSearchFilter.documents => 'Documents',
    GlobalSearchFilter.support => 'Support',
    GlobalSearchFilter.warranties => 'Warranties',
    GlobalSearchFilter.services => 'Services',
  };
}

enum GlobalSearchResultType { appliance, document, support, warranty, service }

extension GlobalSearchResultTypeDetails on GlobalSearchResultType {
  String get label => switch (this) {
    GlobalSearchResultType.appliance => 'Appliance',
    GlobalSearchResultType.document => 'Document',
    GlobalSearchResultType.support => 'Support',
    GlobalSearchResultType.warranty => 'Warranty',
    GlobalSearchResultType.service => 'Service',
  };
}

class GlobalSearchResult {
  const GlobalSearchResult({
    required this.type,
    required this.applianceId,
    required this.title,
    required this.subtitle,
    required this.searchText,
    required this.sortDate,
  });

  final GlobalSearchResultType type;
  final String applianceId;
  final String title;
  final String subtitle;
  final String searchText;
  final DateTime sortDate;
}
