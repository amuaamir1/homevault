import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/appliance.dart';
import '../../models/appliance_form_result.dart';
import '../../services/document_storage_service.dart';
import '../../services/support_action_service.dart';
import '../../state/app_scope.dart';
import '../../widgets/empty_state.dart';
import '../appliances/add_appliance_screen.dart';

enum _SupportFilter {
  all('All'),
  phone('Phone'),
  email('Email'),
  website('Website');

  const _SupportFilter(this.label);

  final String label;
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
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

  final _searchController = TextEditingController();
  final _actionService = const SupportActionService();
  final Set<String> _expandedCategories = {};

  _SupportFilter _filter = _SupportFilter.all;
  String? _expandedApplianceId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on SupportActionException catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  bool _matchesFilter(Appliance appliance) {
    return switch (_filter) {
      _SupportFilter.all => true,
      _SupportFilter.phone => appliance.supportPhone.trim().isNotEmpty,
      _SupportFilter.email => appliance.supportEmail.trim().isNotEmpty,
      _SupportFilter.website => appliance.supportWebsite.trim().isNotEmpty,
    };
  }

  bool _matchesSearch(Appliance appliance) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;

    final searchableText = [
      appliance.name,
      appliance.category,
      appliance.brand,
      appliance.modelNumber,
      appliance.serialNumber,
      appliance.supportProvider,
      appliance.supportPhone,
      appliance.supportEmail,
      appliance.supportWebsite,
      appliance.supportNotes,
    ].join(' ').toLowerCase();

    return searchableText.contains(query);
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

      if (firstIndex != -1) return -1;
      if (secondIndex != -1) return 1;

      return first.toLowerCase().compareTo(second.toLowerCase());
    });

    return categoryList;
  }

  Future<void> _editAppliance(BuildContext context, Appliance appliance) async {
    final result = await Navigator.of(context).push<ApplianceFormResult>(
      MaterialPageRoute(
        builder: (context) => AddApplianceScreen(appliance: appliance),
      ),
    );

    if (result == null || !context.mounted) return;

    try {
      await AppScope.read(context).update(result.appliance);

      for (final document in result.documentsToDelete) {
        try {
          await DocumentStorageService().deleteStoredDocument(document);
        } catch (_) {
          // The record was updated; stale files can be cleaned later.
        }
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.appliance.name} was updated.')),
      );
    } catch (_) {
      for (final document in result.documentsAdded) {
        try {
          await DocumentStorageService().deleteStoredDocument(document);
        } catch (_) {
          // Preserve the original save error if cleanup also fails.
        }
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The support details could not be saved.'),
        ),
      );
    }
  }

  Future<void> _chooseAppliance(BuildContext context) async {
    final appliances = AppScope.read(context).appliances.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (appliances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an appliance before adding support details.'),
        ),
      );
      return;
    }

    final selectedId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose an appliance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: appliances.length,
                itemBuilder: (context, index) {
                  final appliance = appliances[index];

                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(_categoryIcon(appliance.category)),
                    ),
                    title: Text(appliance.name),
                    subtitle: Text(
                      appliance.brand.trim().isEmpty
                          ? appliance.category
                          : appliance.brand,
                    ),
                    trailing: appliance.hasSupportDetails
                        ? const Icon(Icons.check_circle_outline)
                        : const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pop(appliance.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedId == null || !context.mounted) return;

    final appliance = AppScope.read(context).applianceById(selectedId);
    if (appliance != null) {
      await _editAppliance(context, appliance);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allAppliances = AppScope.of(context).appliances;
    final supportAppliances = allAppliances
        .where((appliance) => appliance.hasSupportDetails)
        .where(_matchesFilter)
        .where(_matchesSearch)
        .toList(growable: false);

    final groupedAppliances = _groupAppliances(supportAppliances);
    final categories = _sortedCategories(groupedAppliances.keys);
    final hasSearchQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer support'),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _expandedApplianceId = null;
                });
              },
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
      floatingActionButton: allAppliances.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'support_add_fab',
              onPressed: () => _chooseAppliance(context),
              icon: const Icon(Icons.contact_support_outlined),
              label: const Text('Add support details'),
            ),
      body: allAppliances.isEmpty
          ? const EmptyState(
              icon: Icons.support_agent,
              title: 'No appliances yet',
              message:
                  'Add an appliance first, then save its customer-care contact details here.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) {
                      setState(() {
                        _expandedApplianceId = null;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search appliance, brand, provider, or contact',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _SupportFilter.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _SupportFilter.values[index];

                      return FilterChip(
                        label: Text(filter.label),
                        selected: _filter == filter,
                        onSelected: (_) {
                          setState(() {
                            _filter = filter;
                            _expandedApplianceId = null;
                          });
                        },
                      );
                    },
                  ),
                ),
                Expanded(
                  child: supportAppliances.isEmpty
                      ? EmptyState(
                          icon: Icons.contact_phone_outlined,
                          title:
                              _searchController.text.trim().isEmpty &&
                                  _filter == _SupportFilter.all
                              ? 'No support contacts yet'
                              : 'No matching support contacts',
                          message:
                              _searchController.text.trim().isEmpty &&
                                  _filter == _SupportFilter.all
                              ? 'Add a phone number, email address, or support website to an appliance.'
                              : 'Try another search term or contact filter.',
                          actionLabel:
                              _searchController.text.trim().isEmpty &&
                                  _filter == _SupportFilter.all
                              ? 'Choose appliance'
                              : null,
                          onAction:
                              _searchController.text.trim().isEmpty &&
                                  _filter == _SupportFilter.all
                              ? () => _chooseAppliance(context)
                              : null,
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          children: [
                            _SupportSummary(
                              contactCount: supportAppliances.length,
                              categoryCount: categories.length,
                            ),
                            const SizedBox(height: 12),
                            for (final category in categories) ...[
                              _SupportCategorySection(
                                category: category,
                                appliances: groupedAppliances[category]!,
                                initiallyExpanded:
                                    hasSearchQuery ||
                                    _expandedCategories.contains(category),
                                expandedApplianceId: _expandedApplianceId,
                                onCategoryExpansionChanged: (expanded) {
                                  setState(() {
                                    if (expanded) {
                                      _expandedCategories.add(category);
                                    } else {
                                      _expandedCategories.remove(category);

                                      final expandedId = _expandedApplianceId;
                                      if (expandedId != null &&
                                          groupedAppliances[category]!.any(
                                            (appliance) =>
                                                appliance.id == expandedId,
                                          )) {
                                        _expandedApplianceId = null;
                                      }
                                    }
                                  });
                                },
                                onApplianceExpansionChanged:
                                    (appliance, expanded) {
                                      setState(() {
                                        _expandedApplianceId = expanded
                                            ? appliance.id
                                            : null;
                                      });
                                    },
                                onCall: (appliance) => _runAction(
                                  context,
                                  () => _actionService.call(
                                    appliance.supportPhone,
                                  ),
                                ),
                                onEmail: (appliance) => _runAction(
                                  context,
                                  () => _actionService.email(appliance),
                                ),
                                onWebsite: (appliance) => _runAction(
                                  context,
                                  () => _actionService.openWebsite(
                                    appliance.supportWebsite,
                                  ),
                                ),
                                onCopy: (label, value) =>
                                    _copy(context, label, value),
                                onEdit: (appliance) =>
                                    _editAppliance(context, appliance),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

class _SupportSummary extends StatelessWidget {
  const _SupportSummary({
    required this.contactCount,
    required this.categoryCount,
  });

  final int contactCount;
  final int categoryCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.support_agent_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$contactCount support contact${contactCount == 1 ? '' : 's'} '
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

class _SupportCategorySection extends StatelessWidget {
  const _SupportCategorySection({
    required this.category,
    required this.appliances,
    required this.initiallyExpanded,
    required this.expandedApplianceId,
    required this.onCategoryExpansionChanged,
    required this.onApplianceExpansionChanged,
    required this.onCall,
    required this.onEmail,
    required this.onWebsite,
    required this.onCopy,
    required this.onEdit,
  });

  final String category;
  final List<Appliance> appliances;
  final bool initiallyExpanded;
  final String? expandedApplianceId;
  final ValueChanged<bool> onCategoryExpansionChanged;
  final void Function(Appliance appliance, bool expanded)
  onApplianceExpansionChanged;
  final Future<void> Function(Appliance appliance) onCall;
  final Future<void> Function(Appliance appliance) onEmail;
  final Future<void> Function(Appliance appliance) onWebsite;
  final Future<void> Function(String label, String value) onCopy;
  final Future<void> Function(Appliance appliance) onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey<String>('support-category-$category'),
        initiallyExpanded: initiallyExpanded,
        onExpansionChanged: onCategoryExpansionChanged,
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
            _ExpandableSupportCard(
              appliance: appliances[index],
              expanded: expandedApplianceId == appliances[index].id,
              onExpansionChanged: (expanded) =>
                  onApplianceExpansionChanged(appliances[index], expanded),
              onCall: appliances[index].supportPhone.trim().isEmpty
                  ? null
                  : () => onCall(appliances[index]),
              onEmail: appliances[index].supportEmail.trim().isEmpty
                  ? null
                  : () => onEmail(appliances[index]),
              onWebsite: appliances[index].supportWebsite.trim().isEmpty
                  ? null
                  : () => onWebsite(appliances[index]),
              onCopy: onCopy,
              onEdit: () => onEdit(appliances[index]),
            ),
            if (index < appliances.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ExpandableSupportCard extends StatelessWidget {
  const _ExpandableSupportCard({
    required this.appliance,
    required this.expanded,
    required this.onExpansionChanged,
    required this.onCall,
    required this.onEmail,
    required this.onWebsite,
    required this.onCopy,
    required this.onEdit,
  });

  final Appliance appliance;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final Future<void> Function()? onCall;
  final Future<void> Function()? onEmail;
  final Future<void> Function()? onWebsite;
  final Future<void> Function(String label, String value) onCopy;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    final provider = appliance.supportProvider.trim().isNotEmpty
        ? appliance.supportProvider
        : appliance.brand.trim().isNotEmpty
        ? appliance.brand
        : appliance.category;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => onExpansionChanged(!expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    child: Text(
                      appliance.name.trim().isEmpty
                          ? '?'
                          : appliance.name.trim()[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appliance.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          provider,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _AvailableContactSummary(appliance: appliance),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit support details',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          if (expanded)
            _SupportDetails(
              appliance: appliance,
              onCall: onCall,
              onEmail: onEmail,
              onWebsite: onWebsite,
              onCopy: onCopy,
            ),
        ],
      ),
    );
  }
}

class _AvailableContactSummary extends StatelessWidget {
  const _AvailableContactSummary({required this.appliance});

  final Appliance appliance;

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      if (appliance.supportPhone.trim().isNotEmpty) 'Phone',
      if (appliance.supportEmail.trim().isNotEmpty) 'Email',
      if (appliance.supportWebsite.trim().isNotEmpty) 'Website',
    ];

    return Text(
      items.join(' • '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SupportDetails extends StatelessWidget {
  const _SupportDetails({
    required this.appliance,
    required this.onCall,
    required this.onEmail,
    required this.onWebsite,
    required this.onCopy,
  });

  final Appliance appliance;
  final Future<void> Function()? onCall;
  final Future<void> Function()? onEmail;
  final Future<void> Function()? onWebsite;
  final Future<void> Function(String label, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          if (appliance.supportNotes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(appliance.supportNotes),
            ),
          ],
          if (appliance.hasSupportAction) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onCall != null)
                  FilledButton.tonalIcon(
                    onPressed: onCall,
                    icon: const Icon(Icons.phone_outlined),
                    label: const Text('Call'),
                  ),
                if (onEmail != null)
                  FilledButton.tonalIcon(
                    onPressed: onEmail,
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Email'),
                  ),
                if (onWebsite != null)
                  FilledButton.tonalIcon(
                    onPressed: onWebsite,
                    icon: const Icon(Icons.language),
                    label: const Text('Website'),
                  ),
              ],
            ),
          ],
          const Divider(height: 24),
          if (appliance.supportPhone.trim().isNotEmpty)
            _ContactRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: appliance.supportPhone,
              onCopy: onCopy,
            ),
          if (appliance.supportEmail.trim().isNotEmpty)
            _ContactRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: appliance.supportEmail,
              onCopy: onCopy,
            ),
          if (appliance.supportWebsite.trim().isNotEmpty)
            _ContactRow(
              icon: Icons.language,
              label: 'Website',
              value: appliance.supportWebsite,
              onCopy: onCopy,
            ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;
  final Future<void> Function(String label, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      trailing: IconButton(
        tooltip: 'Copy ${label.toLowerCase()}',
        onPressed: () => onCopy(label, value),
        icon: const Icon(Icons.copy_outlined),
      ),
    );
  }
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
