enum SupportProviderRole {
  manufacturer,
  customerSupport,
  serviceProvider,
  amcProvider,
  warrantyProvider,
  extendedWarrantyProvider,
}

extension SupportProviderRoleDetails on SupportProviderRole {
  String get label => switch (this) {
    SupportProviderRole.manufacturer => 'Manufacturer',
    SupportProviderRole.customerSupport => 'Customer support',
    SupportProviderRole.serviceProvider => 'Service provider',
    SupportProviderRole.amcProvider => 'AMC provider',
    SupportProviderRole.warrantyProvider => 'Warranty provider',
    SupportProviderRole.extendedWarrantyProvider => 'Extended warranty',
  };

  int get sortOrder => switch (this) {
    SupportProviderRole.manufacturer => 0,
    SupportProviderRole.customerSupport => 1,
    SupportProviderRole.serviceProvider => 2,
    SupportProviderRole.amcProvider => 3,
    SupportProviderRole.warrantyProvider => 4,
    SupportProviderRole.extendedWarrantyProvider => 5,
  };
}

enum SupportContactFilter {
  all('All contacts'),
  phone('Phone available'),
  email('Email available'),
  website('Website available'),
  missing('Missing contact');

  const SupportContactFilter(this.label);

  final String label;
}

enum SupportDirectorySort {
  recommended('Recommended'),
  alphabetical('A–Z'),
  mostLinked('Most linked'),
  recentlyUsed('Recently used');

  const SupportDirectorySort(this.label);

  final String label;
}

class SupportDirectoryEntry {
  const SupportDirectoryEntry({
    required this.id,
    required this.name,
    required this.roles,
    required this.phones,
    required this.emails,
    required this.websites,
    required this.notes,
    required this.categories,
    required this.applianceIds,
    required this.applianceNames,
    required this.serviceLocations,
    required this.serviceRequestCount,
    this.lastUsedAt,
  });

  final String id;
  final String name;
  final List<SupportProviderRole> roles;
  final List<String> phones;
  final List<String> emails;
  final List<String> websites;
  final List<String> notes;
  final List<String> categories;
  final List<String> applianceIds;
  final List<String> applianceNames;
  final List<String> serviceLocations;
  final int serviceRequestCount;
  final DateTime? lastUsedAt;

  bool get hasPhone => phones.isNotEmpty;
  bool get hasEmail => emails.isNotEmpty;
  bool get hasWebsite => websites.isNotEmpty;
  bool get hasAnyContact => hasPhone || hasEmail || hasWebsite;
  bool get isManufacturer => roles.contains(SupportProviderRole.manufacturer);
  bool get hasServiceRelationship =>
      roles.contains(SupportProviderRole.serviceProvider) ||
      roles.contains(SupportProviderRole.amcProvider) ||
      roles.contains(SupportProviderRole.customerSupport);

  String get primaryPhone => phones.isEmpty ? '' : phones.first;
  String get primaryEmail => emails.isEmpty ? '' : emails.first;
  String get primaryWebsite => websites.isEmpty ? '' : websites.first;

  String get roleSummary => roles.map((role) => role.label).join(' • ');
}
