import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/appliance.dart';
import '../../state/app_scope.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/warranty_status_chip.dart';
import 'appliance_details_screen.dart';

enum _ApplianceSort {
  nameAscending,
  nameDescending,
  newestAdded,
  oldestAdded,
  warrantyEndingSoon,
}

extension _ApplianceSortLabel on _ApplianceSort {
  String get label => switch (this) {
    _ApplianceSort.nameAscending => 'Name A–Z',
    _ApplianceSort.nameDescending => 'Name Z–A',
    _ApplianceSort.newestAdded => 'Newest added',
    _ApplianceSort.oldestAdded => 'Oldest added',
    _ApplianceSort.warrantyEndingSoon => 'Warranty ending soon',
  };
}

class AppliancesScreen extends StatefulWidget {
  const AppliancesScreen({super.key, required this.onAddAppliance});

  final Future<void> Function() onAddAppliance;

  @override
  State<AppliancesScreen> createState() => _AppliancesScreenState();
}

class _AppliancesScreenState extends State<AppliancesScreen> {
  static const _categoryOrder = [
    'Air Conditioner',
    'Kitchen Appliance',
    'Laundry',
    'Geyser / Water Heater',
    'Television',
    'Computer',
    'Mobile Device',
    'Home Appliance',
    'Other',
  ];

  final Set<String> _expandedCategories = {};
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  String? _categoryFilter;
  WarrantyStatus? _warrantyFilter;
  _ApplianceSort _sort = _ApplianceSort.nameAscending;

  bool get _hasFilters => _categoryFilter != null || _warrantyFilter != null;

  int get _activeFilterCount =>
      (_categoryFilter == null ? 0 : 1) + (_warrantyFilter == null ? 0 : 1);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final allAppliances = store.appliances.toList(growable: false);
    final now = DateTime.now();
    final availableCategories = _sortedCategories(
      allAppliances
          .map((appliance) => _normalizedCategory(appliance.category))
          .toSet(),
    );

    final appliances = allAppliances
        .where((appliance) => _matchesSearch(appliance))
        .where(
          (appliance) =>
              _categoryFilter == null ||
              _normalizedCategory(appliance.category) == _categoryFilter,
        )
        .where(
          (appliance) =>
              _warrantyFilter == null ||
              appliance.warrantyStatusAt(now) == _warrantyFilter,
        )
        .toList(growable: true);

    _sortAppliances(appliances, now);

    final groupedAppliances = _groupAppliances(appliances);
    final categories = _sortedCategories(groupedAppliances.keys);
    final isNarrowed = _query.trim().isNotEmpty || _hasFilters;

    return Scaffold(
      appBar: AppBar(title: const Text('Appliances')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'appliances_add_fab',
        onPressed: widget.onAddAppliance,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: SearchBar(
                key: const ValueKey('applianceSearchField'),
                controller: _searchController,
                hintText: 'Search appliances',
                leading: const Icon(Icons.search),
                trailing: [
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close),
                    ),
                ],
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('applianceFilterButton'),
                      onPressed: () =>
                          _showFilters(context, availableCategories),
                      icon: const Icon(Icons.tune, size: 20),
                      label: Text(
                        _activeFilterCount == 0
                            ? 'Filters'
                            : 'Filters ($_activeFilterCount)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PopupMenuButton<_ApplianceSort>(
                      key: const ValueKey('applianceSortButton'),
                      tooltip: 'Sort appliances',
                      initialValue: _sort,
                      onSelected: (value) => setState(() => _sort = value),
                      itemBuilder: (context) => [
                        for (final option in _ApplianceSort.values)
                          PopupMenuItem(
                            value: option,
                            child: Row(
                              children: [
                                if (option == _sort) ...[
                                  const Icon(Icons.check, size: 18),
                                  const SizedBox(width: 8),
                                ] else
                                  const SizedBox(width: 26),
                                Flexible(child: Text(option.label)),
                              ],
                            ),
                          ),
                      ],
                      child: _ApplianceToolbarButton(
                        icon: Icons.swap_vert,
                        label: _sort.label,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_hasFilters)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (_categoryFilter != null)
                        InputChip(
                          key: const ValueKey('activeCategoryFilterChip'),
                          label: Text(_categoryFilter!),
                          onDeleted: () =>
                              setState(() => _categoryFilter = null),
                        ),
                      if (_warrantyFilter != null)
                        InputChip(
                          key: const ValueKey('activeWarrantyFilterChip'),
                          label: Text(_warrantyStatusLabel(_warrantyFilter!)),
                          onDeleted: () =>
                              setState(() => _warrantyFilter = null),
                        ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: appliances.isEmpty
                  ? EmptyState(
                      icon: allAppliances.isEmpty
                          ? Icons.home_repair_service_outlined
                          : Icons.search_off,
                      title: allAppliances.isEmpty
                          ? 'No appliances yet'
                          : 'No matching appliances',
                      message: allAppliances.isEmpty
                          ? 'Add an appliance to keep its warranty, invoice reference, and support details together.'
                          : 'Try another search or clear one of the active filters.',
                      actionLabel: allAppliances.isEmpty
                          ? 'Add appliance'
                          : isNarrowed
                          ? 'Clear search & filters'
                          : null,
                      onAction: allAppliances.isEmpty
                          ? widget.onAddAppliance
                          : isNarrowed
                          ? _clearSearchAndFilters
                          : null,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      children: [
                        _ApplianceSummary(
                          applianceCount: appliances.length,
                          totalCount: allAppliances.length,
                          categoryCount: categories.length,
                          isFiltered: isNarrowed,
                        ),
                        const SizedBox(height: 12),
                        for (final category in categories) ...[
                          _CategorySection(
                            category: category,
                            appliances: groupedAppliances[category]!,
                            initiallyExpanded:
                                isNarrowed ||
                                _expandedCategories.contains(category),
                            onExpansionChanged: (expanded) {
                              setState(() {
                                if (expanded) {
                                  _expandedCategories.add(category);
                                } else {
                                  _expandedCategories.remove(category);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  Future<void> _clearSearchAndFilters() async {
    _searchController.clear();
    setState(() {
      _query = '';
      _categoryFilter = null;
      _warrantyFilter = null;
    });
  }

  bool _matchesSearch(Appliance appliance) {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    final searchableValues = <String>[
      appliance.name,
      appliance.brand,
      appliance.category,
      appliance.modelNumber,
      appliance.serialNumber,
      appliance.supportProvider,
      appliance.supportPhone,
      appliance.supportEmail,
      appliance.supportWebsite,
      appliance.invoiceReference,
      appliance.warrantyProvider,
      appliance.warrantyReference,
      appliance.extendedWarrantyProvider,
      appliance.extendedWarrantyReference,
      appliance.amcProvider,
      appliance.amcReference,
      appliance.amcPhone,
      appliance.amcNotes,
      appliance.warrantyClaimNumber,
      appliance.notes,
      ...appliance.allDocuments.expand(
        (document) => [
          document.displayTitle,
          document.fileName,
          document.reference,
        ],
      ),
      ...appliance.serviceRecords.expand(
        (record) => [
          record.provider,
          record.technicianName,
          record.ticketNumber,
          record.problemDescription,
        ],
      ),
    ];

    final searchableText = searchableValues
        .where((value) => value.trim().isNotEmpty)
        .join(' ')
        .toLowerCase();

    final terms = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);

    return terms.every(searchableText.contains);
  }

  Map<String, List<Appliance>> _groupAppliances(List<Appliance> appliances) {
    final grouped = <String, List<Appliance>>{};

    for (final appliance in appliances) {
      final category = _normalizedCategory(appliance.category);
      grouped.putIfAbsent(category, () => []).add(appliance);
    }

    return grouped;
  }

  String _normalizedCategory(String category) {
    final trimmed = category.trim();
    return trimmed.isEmpty ? 'Other' : trimmed;
  }

  void _sortAppliances(List<Appliance> appliances, DateTime now) {
    appliances.sort((first, second) {
      final comparison = switch (_sort) {
        _ApplianceSort.nameAscending => _compareNames(first, second),
        _ApplianceSort.nameDescending => _compareNames(second, first),
        _ApplianceSort.newestAdded => second.createdAt.compareTo(
          first.createdAt,
        ),
        _ApplianceSort.oldestAdded => first.createdAt.compareTo(
          second.createdAt,
        ),
        _ApplianceSort.warrantyEndingSoon => _compareWarrantyEndingSoon(
          first,
          second,
          now,
        ),
      };

      return comparison == 0 ? _compareNames(first, second) : comparison;
    });
  }

  int _compareNames(Appliance first, Appliance second) =>
      first.name.toLowerCase().compareTo(second.name.toLowerCase());

  int _compareWarrantyEndingSoon(
    Appliance first,
    Appliance second,
    DateTime now,
  ) {
    final firstExpiry = first.effectiveWarrantyExpiryDate;
    final secondExpiry = second.effectiveWarrantyExpiryDate;

    final firstRank = _warrantySortRank(firstExpiry, now);
    final secondRank = _warrantySortRank(secondExpiry, now);
    final rankComparison = firstRank.compareTo(secondRank);
    if (rankComparison != 0) return rankComparison;

    if (firstExpiry == null && secondExpiry == null) return 0;
    if (firstExpiry == null) return 1;
    if (secondExpiry == null) return -1;

    if (firstRank == 0) {
      return firstExpiry.compareTo(secondExpiry);
    }

    return secondExpiry.compareTo(firstExpiry);
  }

  int _warrantySortRank(DateTime? expiry, DateTime now) {
    if (expiry == null) return 2;

    final today = DateTime(now.year, now.month, now.day);
    final expiryDate = DateTime(expiry.year, expiry.month, expiry.day);
    return expiryDate.isBefore(today) ? 1 : 0;
  }

  Future<void> _showFilters(
    BuildContext context,
    List<String> availableCategories,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void update(VoidCallback change) {
              setState(change);
              setSheetState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter appliances',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('applianceCategoryFilter'),
                      initialValue: _categoryFilter ?? '',
                      decoration: const InputDecoration(labelText: 'Category'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All categories'),
                        ),
                        for (final category in availableCategories)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                      ],
                      onChanged: (value) {
                        update(() {
                          _categoryFilter = value == null || value.isEmpty
                              ? null
                              : value;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Warranty status',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          key: const ValueKey('warrantyFilter-all'),
                          label: const Text('All'),
                          selected: _warrantyFilter == null,
                          onSelected: (_) =>
                              update(() => _warrantyFilter = null),
                        ),
                        for (final status in WarrantyStatus.values)
                          ChoiceChip(
                            key: ValueKey('warrantyFilter-${status.name}'),
                            label: Text(_warrantyStatusLabel(status)),
                            selected: _warrantyFilter == status,
                            onSelected: (_) =>
                                update(() => _warrantyFilter = status),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                          key: const ValueKey('resetApplianceFiltersButton'),
                          onPressed: _hasFilters
                              ? () => update(() {
                                  _categoryFilter = null;
                                  _warrantyFilter = null;
                                })
                              : null,
                          child: const Text('Reset'),
                        ),
                        const Spacer(),
                        FilledButton(
                          key: const ValueKey('doneApplianceFiltersButton'),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _warrantyStatusLabel(WarrantyStatus status) => switch (status) {
    WarrantyStatus.active => 'Active',
    WarrantyStatus.expiringSoon => 'Expiring soon',
    WarrantyStatus.expired => 'Expired',
    WarrantyStatus.notProvided => 'No warranty date',
  };

  List<String> _sortedCategories(Iterable<String> categories) {
    final categoryList = categories.toList();

    categoryList.sort((first, second) {
      final firstIndex = _categoryOrder.indexOf(first);
      final secondIndex = _categoryOrder.indexOf(second);

      if (firstIndex != -1 && secondIndex != -1) {
        return firstIndex.compareTo(secondIndex);
      }

      if (firstIndex != -1) {
        return -1;
      }

      if (secondIndex != -1) {
        return 1;
      }

      return first.toLowerCase().compareTo(second.toLowerCase());
    });

    return categoryList;
  }
}

class _ApplianceToolbarButton extends StatelessWidget {
  const _ApplianceToolbarButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
    );
  }
}

class _ApplianceSummary extends StatelessWidget {
  const _ApplianceSummary({
    required this.applianceCount,
    required this.totalCount,
    required this.categoryCount,
    required this.isFiltered,
  });

  final int applianceCount;
  final int totalCount;
  final int categoryCount;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final countLabel = isFiltered && applianceCount != totalCount
        ? '$applianceCount of $totalCount appliances'
        : '$applianceCount appliance${applianceCount == 1 ? '' : 's'}';

    return Row(
      children: [
        Icon(
          Icons.inventory_2_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$countLabel across $categoryCount '
            'categor${categoryCount == 1 ? 'y' : 'ies'}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.appliances,
    required this.initiallyExpanded,
    required this.onExpansionChanged,
  });

  final String category;
  final List<Appliance> appliances;
  final bool initiallyExpanded;
  final ValueChanged<bool> onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // ExpansionTile keeps its own state. The key must change when a
        // search/filter switches a category from collapsed to forced-open;
        // otherwise `initiallyExpanded` is ignored after the first build.
        key: PageStorageKey<String>(
          'appliance-category-$category-${initiallyExpanded ? 'expanded' : 'collapsed'}',
        ),
        initiallyExpanded: initiallyExpanded,
        onExpansionChanged: onExpansionChanged,
        leading: CircleAvatar(child: Icon(_categoryIcon(category))),
        title: Text(
          category,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${appliances.length} appliance${appliances.length == 1 ? '' : 's'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          for (var index = 0; index < appliances.length; index++) ...[
            _ApplianceListTile(appliance: appliances[index]),
            if (index < appliances.length - 1)
              const Divider(height: 1, indent: 58),
          ],
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    final normalized = category.toLowerCase();

    if (normalized.contains('air')) {
      return Icons.ac_unit;
    }
    if (normalized.contains('kitchen')) {
      return Icons.kitchen_outlined;
    }
    if (normalized.contains('laundry')) {
      return Icons.local_laundry_service_outlined;
    }
    if (normalized.contains('geyser') || normalized.contains('water heater')) {
      return Icons.water_drop_outlined;
    }
    if (normalized.contains('television')) {
      return Icons.tv;
    }
    if (normalized.contains('computer')) {
      return Icons.computer;
    }
    if (normalized.contains('mobile')) {
      return Icons.smartphone;
    }
    if (normalized.contains('home appliance')) {
      return Icons.home_outlined;
    }

    return Icons.devices_other;
  }
}

class _ApplianceListPhoto extends StatelessWidget {
  const _ApplianceListPhoto({required this.appliance, required this.fallback});

  final Appliance appliance;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final path = appliance.appliancePhotoDocument?.localPath.trim() ?? '';
    if (path.isEmpty) {
      return CircleAvatar(
        radius: 21,
        child: Text(
          fallback,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    return CircleAvatar(
      radius: 21,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ClipOval(
        child: Image.file(
          File(path),
          excludeFromSemantics: true,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Center(
            child: Text(
              fallback,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _ApplianceListTile extends StatelessWidget {
  const _ApplianceListTile({required this.appliance});

  final Appliance appliance;

  @override
  Widget build(BuildContext context) {
    final secondaryText = [
      appliance.brand,
      appliance.modelNumber,
    ].where((value) => value.trim().isNotEmpty).join(' • ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: _ApplianceListPhoto(
        appliance: appliance,
        fallback: _initial(appliance.name),
      ),
      title: Text(
        appliance.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (secondaryText.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(secondaryText, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 7),
          WarrantyStatusChip(
            status: appliance.warrantyStatusAt(DateTime.now()),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                ApplianceDetailsScreen(applianceId: appliance.id),
          ),
        );
      },
    );
  }

  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }
}
