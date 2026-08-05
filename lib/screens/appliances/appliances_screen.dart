import 'package:flutter/material.dart';

import '../../models/appliance.dart';
import '../../state/app_scope.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/warranty_status_chip.dart';
import 'appliance_details_screen.dart';

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
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final query = _query.trim().toLowerCase();

    final appliances = store.appliances
        .where((appliance) {
          if (query.isEmpty) {
            return true;
          }

          return appliance.name.toLowerCase().contains(query) ||
              appliance.brand.toLowerCase().contains(query) ||
              appliance.category.toLowerCase().contains(query) ||
              appliance.modelNumber.toLowerCase().contains(query) ||
              appliance.serialNumber.toLowerCase().contains(query);
        })
        .toList(growable: false);

    final groupedAppliances = _groupAppliances(appliances);
    final categories = _sortedCategories(groupedAppliances.keys);

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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SearchBar(
                hintText: 'Search appliances',
                leading: const Icon(Icons.search),
                trailing: [
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      onPressed: () => setState(() => _query = ''),
                      icon: const Icon(Icons.close),
                    ),
                ],
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: appliances.isEmpty
                  ? EmptyState(
                      icon: query.isEmpty
                          ? Icons.home_repair_service_outlined
                          : Icons.search_off,
                      title: query.isEmpty
                          ? 'No appliances yet'
                          : 'No matching appliances',
                      message: query.isEmpty
                          ? 'Add an appliance to keep its warranty, invoice reference, and support details together.'
                          : 'Try another name, brand, model, serial number, or category.',
                      actionLabel: query.isEmpty ? 'Add appliance' : null,
                      onAction: query.isEmpty ? widget.onAddAppliance : null,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      children: [
                        _ApplianceSummary(
                          applianceCount: appliances.length,
                          categoryCount: categories.length,
                        ),
                        const SizedBox(height: 12),
                        for (final category in categories) ...[
                          _CategorySection(
                            category: category,
                            appliances: groupedAppliances[category]!,
                            initiallyExpanded:
                                query.isNotEmpty ||
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

  Map<String, List<Appliance>> _groupAppliances(List<Appliance> appliances) {
    final grouped = <String, List<Appliance>>{};

    for (final appliance in appliances) {
      final category = appliance.category.trim().isEmpty
          ? 'Other'
          : appliance.category.trim();

      grouped.putIfAbsent(category, () => []).add(appliance);
    }

    for (final categoryAppliances in grouped.values) {
      categoryAppliances.sort(
        (first, second) =>
            first.name.toLowerCase().compareTo(second.name.toLowerCase()),
      );
    }

    return grouped;
  }

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

class _ApplianceSummary extends StatelessWidget {
  const _ApplianceSummary({
    required this.applianceCount,
    required this.categoryCount,
  });

  final int applianceCount;
  final int categoryCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.inventory_2_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$applianceCount appliance${applianceCount == 1 ? '' : 's'} '
            'across $categoryCount categor${categoryCount == 1 ? 'y' : 'ies'}',
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
        key: PageStorageKey<String>('appliance-category-$category'),
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
      leading: CircleAvatar(
        radius: 21,
        child: Text(
          _initial(appliance.name),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
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
