import '../models/appliance.dart';
import '../models/service_request.dart';
import '../models/support_directory_entry.dart';

class SupportDirectoryService {
  const SupportDirectoryService();

  List<SupportDirectoryEntry> buildDirectory(List<Appliance> appliances) {
    final builders = <String, _EntryBuilder>{};

    for (final appliance in appliances) {
      final brand = appliance.brand.trim();
      final supportProvider = appliance.supportProvider.trim();
      final hasSupportContact =
          appliance.supportPhone.trim().isNotEmpty ||
          appliance.supportEmail.trim().isNotEmpty ||
          appliance.supportWebsite.trim().isNotEmpty ||
          appliance.supportNotes.trim().isNotEmpty;

      if (brand.isNotEmpty) {
        final brandBuilder = _builderFor(builders, brand);
        brandBuilder.addAppliance(appliance);
        brandBuilder.roles.add(SupportProviderRole.manufacturer);

        if (_sameName(supportProvider, brand) ||
            (supportProvider.isEmpty && hasSupportContact)) {
          brandBuilder.roles.add(SupportProviderRole.customerSupport);
          brandBuilder.addPhone(appliance.supportPhone);
          brandBuilder.addEmail(appliance.supportEmail);
          brandBuilder.addWebsite(appliance.supportWebsite);
          brandBuilder.addNote(appliance.supportNotes);
        }
      }

      if (supportProvider.isNotEmpty || hasSupportContact) {
        final providerName = supportProvider.isNotEmpty
            ? supportProvider
            : brand.isNotEmpty
            ? brand
            : '${appliance.name} support';
        final builder = _builderFor(builders, providerName);
        builder.addAppliance(appliance);
        builder.roles.add(SupportProviderRole.customerSupport);
        if (brand.isNotEmpty && _sameName(providerName, brand)) {
          builder.roles.add(SupportProviderRole.manufacturer);
        }
        builder.addPhone(appliance.supportPhone);
        builder.addEmail(appliance.supportEmail);
        builder.addWebsite(appliance.supportWebsite);
        builder.addNote(appliance.supportNotes);
      }

      _addCoverageProvider(
        builders,
        appliance,
        appliance.warrantyProvider,
        SupportProviderRole.warrantyProvider,
      );
      _addCoverageProvider(
        builders,
        appliance,
        appliance.extendedWarrantyProvider,
        SupportProviderRole.extendedWarrantyProvider,
      );

      final amcProvider = appliance.amcProvider.trim();
      if (amcProvider.isNotEmpty) {
        final builder = _builderFor(builders, amcProvider);
        builder.addAppliance(appliance);
        builder.roles.add(SupportProviderRole.amcProvider);
        builder.addPhone(appliance.amcPhone);
        builder.addNote(appliance.amcNotes);
      }

      for (final request in appliance.serviceRequests) {
        _addServiceRequest(builders, appliance, request);
      }
    }

    final entries = builders.values
        .map((builder) => builder.build())
        .toList(growable: false);

    return sortEntries(entries, SupportDirectorySort.recommended);
  }

  List<SupportDirectoryEntry> filterEntries(
    List<SupportDirectoryEntry> entries, {
    String query = '',
    SupportProviderRole? role,
    String? category,
    String? location,
    SupportContactFilter contactFilter = SupportContactFilter.all,
    SupportDirectorySort sort = SupportDirectorySort.recommended,
  }) {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);

    final filtered = entries
        .where((entry) {
          if (role != null && !entry.roles.contains(role)) return false;
          if (category != null &&
              category.isNotEmpty &&
              !entry.categories.contains(category)) {
            return false;
          }
          if (location != null &&
              location.isNotEmpty &&
              !entry.serviceLocations.contains(location)) {
            return false;
          }

          final contactMatches = switch (contactFilter) {
            SupportContactFilter.all => true,
            SupportContactFilter.phone => entry.hasPhone,
            SupportContactFilter.email => entry.hasEmail,
            SupportContactFilter.website => entry.hasWebsite,
            SupportContactFilter.missing => !entry.hasAnyContact,
          };
          if (!contactMatches) return false;

          if (terms.isEmpty) return true;
          final searchable = <String>[
            entry.name,
            ...entry.roles.map((role) => role.label),
            ...entry.phones,
            ...entry.emails,
            ...entry.websites,
            ...entry.notes,
            ...entry.categories,
            ...entry.applianceNames,
            ...entry.serviceLocations,
          ].join(' ').toLowerCase();

          return terms.every(searchable.contains);
        })
        .toList(growable: false);

    return sortEntries(filtered, sort);
  }

  List<SupportDirectoryEntry> sortEntries(
    List<SupportDirectoryEntry> entries,
    SupportDirectorySort sort,
  ) {
    final result = [...entries];
    result.sort((a, b) {
      final comparison = switch (sort) {
        SupportDirectorySort.alphabetical => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        SupportDirectorySort.mostLinked => b.applianceIds.length.compareTo(
          a.applianceIds.length,
        ),
        SupportDirectorySort.recentlyUsed => _compareRecent(a, b),
        SupportDirectorySort.recommended => _compareRecommended(a, b),
      };
      if (comparison != 0) return comparison;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  List<String> categories(List<SupportDirectoryEntry> entries) {
    final values = <String>{};
    for (final entry in entries) {
      values.addAll(entry.categories);
    }
    return values.toList()..sort((a, b) => a.compareTo(b));
  }

  List<String> locations(List<SupportDirectoryEntry> entries) {
    final values = <String>{};
    for (final entry in entries) {
      values.addAll(entry.serviceLocations);
    }
    return values.toList()..sort((a, b) => a.compareTo(b));
  }

  static String compactServiceLocation(String address) {
    final parts = address
        .split(RegExp(r'[,\n]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;

    final take = parts.length >= 3 ? 3 : 2;
    return parts.sublist(parts.length - take).join(', ');
  }

  static int _compareRecommended(
    SupportDirectoryEntry a,
    SupportDirectoryEntry b,
  ) {
    final aScore = _recommendationScore(a);
    final bScore = _recommendationScore(b);
    return bScore.compareTo(aScore);
  }

  static int _recommendationScore(SupportDirectoryEntry entry) {
    var score = entry.applianceIds.length * 10;
    if (entry.hasAnyContact) score += 8;
    if (entry.hasPhone) score += 3;
    if (entry.roles.contains(SupportProviderRole.amcProvider)) score += 4;
    if (entry.roles.contains(SupportProviderRole.customerSupport)) score += 3;
    score += entry.serviceRequestCount * 2;
    return score;
  }

  static int _compareRecent(SupportDirectoryEntry a, SupportDirectoryEntry b) {
    final aDate = a.lastUsedAt;
    final bDate = b.lastUsedAt;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  }

  void _addCoverageProvider(
    Map<String, _EntryBuilder> builders,
    Appliance appliance,
    String rawName,
    SupportProviderRole role,
  ) {
    final name = rawName.trim();
    if (name.isEmpty) return;

    final builder = _builderFor(builders, name);
    builder.addAppliance(appliance);
    builder.roles.add(role);

    final supportName = appliance.supportProvider.trim();
    final brand = appliance.brand.trim();
    if (_sameName(name, supportName) || _sameName(name, brand)) {
      builder.addPhone(appliance.supportPhone);
      builder.addEmail(appliance.supportEmail);
      builder.addWebsite(appliance.supportWebsite);
    }
  }

  void _addServiceRequest(
    Map<String, _EntryBuilder> builders,
    Appliance appliance,
    ServiceRequest request,
  ) {
    final provider = request.provider.trim();
    if (provider.isEmpty) return;

    final builder = _builderFor(builders, provider);
    builder.addAppliance(appliance);
    builder.roles.add(SupportProviderRole.serviceProvider);
    builder.addPhone(request.providerPhone);
    builder.serviceRequestCount += 1;
    final location = compactServiceLocation(request.serviceAddress);
    if (location.isNotEmpty) builder.serviceLocations.add(location);
    if (builder.lastUsedAt == null ||
        request.updatedAt.isAfter(builder.lastUsedAt!)) {
      builder.lastUsedAt = request.updatedAt;
    }
  }

  _EntryBuilder _builderFor(
    Map<String, _EntryBuilder> builders,
    String providerName,
  ) {
    final key = _normalizeName(providerName);
    return builders.putIfAbsent(
      key,
      () => _EntryBuilder(id: key, name: providerName.trim()),
    );
  }

  static bool _sameName(String a, String b) {
    if (a.trim().isEmpty || b.trim().isEmpty) return false;
    return _normalizeName(a) == _normalizeName(b);
  }

  static String _normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _EntryBuilder {
  _EntryBuilder({required this.id, required this.name});

  final String id;
  final String name;
  final Set<SupportProviderRole> roles = {};
  final Set<String> phones = {};
  final Set<String> emails = {};
  final Set<String> websites = {};
  final Set<String> notes = {};
  final Set<String> categories = {};
  final Set<String> applianceIds = {};
  final Map<String, String> applianceNames = {};
  final Set<String> serviceLocations = {};
  int serviceRequestCount = 0;
  DateTime? lastUsedAt;

  void addAppliance(Appliance appliance) {
    applianceIds.add(appliance.id);
    applianceNames[appliance.id] = appliance.name;
    final category = appliance.category.trim();
    if (category.isNotEmpty) categories.add(category);
  }

  void addPhone(String value) => _addValue(phones, value);
  void addEmail(String value) => _addValue(emails, value);
  void addWebsite(String value) => _addValue(websites, value);
  void addNote(String value) => _addValue(notes, value);

  void _addValue(Set<String> target, String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) target.add(trimmed);
  }

  SupportDirectoryEntry build() {
    final sortedRoles = roles.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final sortedCategories = categories.toList()..sort();
    final sortedNames = applianceNames.values.toSet().toList()..sort();
    final sortedLocations = serviceLocations.toList()..sort();

    return SupportDirectoryEntry(
      id: id,
      name: name,
      roles: List.unmodifiable(sortedRoles),
      phones: List.unmodifiable(phones),
      emails: List.unmodifiable(emails),
      websites: List.unmodifiable(websites),
      notes: List.unmodifiable(notes),
      categories: List.unmodifiable(sortedCategories),
      applianceIds: List.unmodifiable(applianceIds),
      applianceNames: List.unmodifiable(sortedNames),
      serviceLocations: List.unmodifiable(sortedLocations),
      serviceRequestCount: serviceRequestCount,
      lastUsedAt: lastUsedAt,
    );
  }
}
