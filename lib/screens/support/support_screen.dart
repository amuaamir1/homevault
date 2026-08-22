import 'package:flutter/material.dart';

import '../../models/appliance.dart';
import '../../models/appliance_form_result.dart';
import '../../models/service_request_form_result.dart';
import '../../models/support_directory_entry.dart';
import '../../profile/profile_scope.dart';
import '../../services/document_storage_service.dart';
import '../../services/homevault_error_presenter.dart';
import '../../services/support_action_service.dart';
import '../../services/support_directory_service.dart';
import '../../state/app_scope.dart';
import '../../widgets/empty_state.dart';
import '../appliances/add_appliance_screen.dart';
import '../service/add_service_request_screen.dart';
import 'provider_details_screen.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _searchController = TextEditingController();
  final _directoryService = const SupportDirectoryService();
  final _actionService = const SupportActionService();

  SupportProviderRole? _role;
  SupportContactFilter _contactFilter = SupportContactFilter.all;
  SupportDirectorySort _sort = SupportDirectorySort.recommended;
  String? _category;
  String? _location;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The provider action could not be opened. Please try again.',
      );
    }
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
          // The appliance update succeeded; stale local files can be retried.
        }
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.appliance.name} was updated.')),
      );
    } catch (error) {
      for (final document in result.documentsAdded) {
        try {
          await DocumentStorageService().deleteStoredDocument(document);
        } catch (_) {
          // Preserve the original save failure.
        }
      }
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The support details could not be saved. Please try again.',
      );
    }
  }

  Future<void> _chooseAppliance(BuildContext context) async {
    final appliances = AppScope.read(context).appliances.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (appliances.isEmpty) return;

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
                    leading: const Icon(Icons.devices_other_outlined),
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
    if (appliance != null) await _editAppliance(context, appliance);
  }

  Future<String?> _chooseLinkedAppliance(
    BuildContext context,
    SupportDirectoryEntry entry,
  ) async {
    final store = AppScope.read(context);
    final linked =
        store.appliances
            .where((appliance) => entry.applianceIds.contains(appliance.id))
            .toList(growable: false)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    if (linked.isEmpty) return null;
    if (linked.length == 1) return linked.first.id;

    return showModalBottomSheet<String>(
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
                  'Request service for',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: linked.length,
                itemBuilder: (context, index) {
                  final appliance = linked[index];
                  return ListTile(
                    leading: const Icon(Icons.devices_other_outlined),
                    title: Text(appliance.name),
                    subtitle: Text(appliance.category),
                    onTap: () => Navigator.of(context).pop(appliance.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestService(
    BuildContext context,
    SupportDirectoryEntry entry,
  ) async {
    final applianceId = await _chooseLinkedAppliance(context, entry);
    if (applianceId == null || !context.mounted) return;

    final store = AppScope.read(context);
    final profile = ProfileScope.read(context).profile;
    final result = await Navigator.of(context).push<ServiceRequestFormResult>(
      MaterialPageRoute(
        builder: (context) => AddServiceRequestScreen(
          appliances: store.appliances.toList(growable: false),
          initialApplianceId: applianceId,
          initialProfile: profile,
          initialProviderName: entry.name,
          initialProviderPhone: entry.primaryPhone,
        ),
      ),
    );

    if (result == null || !context.mounted) return;
    try {
      await store.addServiceRequest(result.applianceId, result.request);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Service request saved with ${entry.name}.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The service request could not be saved. Please try again.',
      );
    }
  }

  Future<void> _openProvider(
    BuildContext context,
    SupportDirectoryEntry entry,
  ) async {
    final appliances = AppScope.read(
      context,
    ).appliances.toList(growable: false);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (detailsContext) => ProviderDetailsScreen(
          entry: entry,
          appliances: appliances,
          onRequestService: () => _requestService(detailsContext, entry),
          onEditAppliance: (appliance) async {
            await _editAppliance(detailsContext, appliance);
            if (detailsContext.mounted) Navigator.of(detailsContext).pop();
          },
        ),
      ),
    );
  }

  Future<void> _showFilters(
    BuildContext context,
    List<String> categories,
    List<String> locations,
  ) async {
    var category = _category;
    var location = _location;
    var contact = _contactFilter;
    var sort = _sort;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
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
                  'Directory filters',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: category ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Appliance category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('All categories'),
                    ),
                    ...categories.map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    ),
                  ],
                  onChanged: (value) => setSheetState(
                    () => category = value == null || value.isEmpty
                        ? null
                        : value,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: location ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Service location',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('All saved locations'),
                    ),
                    ...locations.map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) => setSheetState(
                    () => location = value == null || value.isEmpty
                        ? null
                        : value,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SupportContactFilter>(
                  initialValue: contact,
                  decoration: const InputDecoration(
                    labelText: 'Contact availability',
                    prefixIcon: Icon(Icons.contact_phone_outlined),
                  ),
                  items: SupportContactFilter.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setSheetState(() => contact = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SupportDirectorySort>(
                  initialValue: sort,
                  decoration: const InputDecoration(
                    labelText: 'Sort by',
                    prefixIcon: Icon(Icons.sort),
                  ),
                  items: SupportDirectorySort.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setSheetState(() => sort = value);
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          category = null;
                          location = null;
                          contact = SupportContactFilter.all;
                          sort = SupportDirectorySort.recommended;
                        });
                      },
                      child: const Text('Reset'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (applied != true || !mounted) return;
    setState(() {
      _category = category;
      _location = location;
      _contactFilter = contact;
      _sort = sort;
    });
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _role = null;
      _contactFilter = SupportContactFilter.all;
      _sort = SupportDirectorySort.recommended;
      _category = null;
      _location = null;
    });
  }

  bool get _hasAdvancedFilter =>
      _category != null ||
      _location != null ||
      _contactFilter != SupportContactFilter.all ||
      _sort != SupportDirectorySort.recommended;

  @override
  Widget build(BuildContext context) {
    final appliances = AppScope.of(context).appliances;
    final directory = _directoryService.buildDirectory(appliances);
    final categories = _directoryService.categories(directory);
    final locations = _directoryService.locations(directory);
    final visible = _directoryService.filterEntries(
      directory,
      query: _searchController.text,
      role: _role,
      category: _category,
      location: _location,
      contactFilter: _contactFilter,
      sort: _sort,
    );

    final manufacturerCount = directory
        .where((entry) => entry.isManufacturer)
        .length;
    final serviceCount = directory
        .where((entry) => entry.hasServiceRelationship)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider directory'),
        actions: [
          IconButton(
            tooltip: 'Filter and sort',
            onPressed: () => _showFilters(context, categories, locations),
            icon: Badge(
              isLabelVisible: _hasAdvancedFilter,
              child: const Icon(Icons.tune),
            ),
          ),
          if (_searchController.text.isNotEmpty ||
              _role != null ||
              _hasAdvancedFilter)
            IconButton(
              tooltip: 'Clear directory filters',
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all),
            ),
        ],
      ),
      floatingActionButton: appliances.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'support_add_fab',
              onPressed: () => _chooseAppliance(context),
              icon: const Icon(Icons.contact_support_outlined),
              label: const Text('Add support details'),
            ),
      body: appliances.isEmpty
          ? const EmptyState(
              icon: Icons.support_agent,
              title: 'No appliances yet',
              message:
                  'Add an appliance first. HomeVault will then build your manufacturer and service-provider directory from saved support, warranty, AMC, and service data.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    key: const Key('providerDirectorySearchField'),
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText:
                          'Search provider, appliance, category, or location',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _role == null,
                        onSelected: (_) => setState(() => _role = null),
                      ),
                      const SizedBox(width: 8),
                      for (final role in SupportProviderRole.values) ...[
                        ChoiceChip(
                          label: Text(role.label),
                          selected: _role == role,
                          onSelected: (_) => setState(() => _role = role),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? EmptyState(
                          icon: Icons.business_outlined,
                          title: directory.isEmpty
                              ? 'No providers yet'
                              : 'No matching providers',
                          message: directory.isEmpty
                              ? 'Add manufacturer, customer-care, AMC, warranty, or service-provider details to an appliance.'
                              : 'Try a different search term or clear some filters.',
                          actionLabel: directory.isEmpty
                              ? 'Choose appliance'
                              : 'Clear filters',
                          onAction: directory.isEmpty
                              ? () async => _chooseAppliance(context)
                              : () async => _clearAllFilters(),
                        )
                      : ListView.separated(
                          key: const Key('providerDirectoryList'),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: visible.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _DirectorySummary(
                                providerCount: directory.length,
                                manufacturerCount: manufacturerCount,
                                serviceCount: serviceCount,
                                visibleCount: visible.length,
                              );
                            }

                            final entry = visible[index - 1];
                            return _ProviderCard(
                              entry: entry,
                              onTap: () => _openProvider(context, entry),
                              onCall: entry.hasPhone
                                  ? () => _runAction(
                                      context,
                                      () => _actionService.call(
                                        entry.primaryPhone,
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _DirectorySummary extends StatelessWidget {
  const _DirectorySummary({
    required this.providerCount,
    required this.manufacturerCount,
    required this.serviceCount,
    required this.visibleCount,
  });

  final int providerCount;
  final int manufacturerCount;
  final int serviceCount;
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.hub_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$providerCount provider${providerCount == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$manufacturerCount manufacturer${manufacturerCount == 1 ? '' : 's'} • '
                    '$serviceCount service contact${serviceCount == 1 ? '' : 's'}'
                    '${visibleCount == providerCount ? '' : ' • $visibleCount shown'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.entry,
    required this.onTap,
    required this.onCall,
  });

  final SupportDirectoryEntry entry;
  final VoidCallback onTap;
  final Future<void> Function()? onCall;

  @override
  Widget build(BuildContext context) {
    final contactSummary = <String>[
      if (entry.hasPhone) 'Phone',
      if (entry.hasEmail) 'Email',
      if (entry.hasWebsite) 'Website',
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                child: Text(
                  entry.name.isEmpty ? '?' : entry.name[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.roleSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${entry.applianceIds.length} linked appliance${entry.applianceIds.length == 1 ? '' : 's'}'
                      '${entry.categories.isEmpty ? '' : ' • ${entry.categories.join(', ')}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      contactSummary.isEmpty
                          ? 'Contact details not saved'
                          : contactSummary.join(' • '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: contactSummary.isEmpty
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (entry.serviceLocations.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              entry.serviceLocations.first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (onCall != null)
                IconButton(
                  tooltip: 'Call ${entry.name}',
                  onPressed: onCall,
                  icon: const Icon(Icons.phone_outlined),
                )
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
