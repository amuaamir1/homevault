import 'package:flutter/material.dart';

import '../../models/appliance.dart';
import '../../models/service_form_result.dart';
import '../../models/service_record.dart';
import '../../services/document_storage_service.dart';
import '../../state/app_scope.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/service_record_tile.dart';
import 'add_service_record_screen.dart';

enum ServiceFilter { all, active, scheduled, completed, cancelled, dueSoon }

enum ServiceSort { newest, oldest, nextService, highestCost }

extension ServiceFilterLabel on ServiceFilter {
  String get label => switch (this) {
    ServiceFilter.all => 'All',
    ServiceFilter.active => 'Active',
    ServiceFilter.scheduled => 'Scheduled',
    ServiceFilter.completed => 'Completed',
    ServiceFilter.cancelled => 'Cancelled',
    ServiceFilter.dueSoon => 'Due soon',
  };
}

extension ServiceSortLabel on ServiceSort {
  String get label => switch (this) {
    ServiceSort.newest => 'Newest service',
    ServiceSort.oldest => 'Oldest service',
    ServiceSort.nextService => 'Next service date',
    ServiceSort.highestCost => 'Highest cost',
  };
}

class ServiceCenterScreen extends StatefulWidget {
  const ServiceCenterScreen({
    super.key,
    this.initialFilter = ServiceFilter.all,
  });

  final ServiceFilter initialFilter;

  @override
  State<ServiceCenterScreen> createState() => _ServiceCenterScreenState();
}

class _ServiceCenterScreenState extends State<ServiceCenterScreen> {
  final _searchController = TextEditingController();
  late ServiceFilter _filter;
  ServiceSort _sort = ServiceSort.newest;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _searchController.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  List<_ServiceEntry> _entries(List<Appliance> appliances) {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final result = <_ServiceEntry>[];

    for (final appliance in appliances) {
      for (final record in appliance.serviceRecords) {
        final entry = _ServiceEntry(appliance: appliance, record: record);
        if (!_matchesFilter(entry, now)) continue;

        if (query.isNotEmpty) {
          final searchable = [
            appliance.name,
            appliance.brand,
            record.provider,
            record.technicianName,
            record.ticketNumber,
            record.problemDescription,
            record.workCompleted,
            record.partsReplaced,
            record.status.label,
          ].join(' ').toLowerCase();
          if (!searchable.contains(query)) continue;
        }
        result.add(entry);
      }
    }

    result.sort((a, b) {
      return switch (_sort) {
        ServiceSort.newest => b.record.serviceDate.compareTo(
          a.record.serviceDate,
        ),
        ServiceSort.oldest => a.record.serviceDate.compareTo(
          b.record.serviceDate,
        ),
        ServiceSort.nextService => _compareNullableDates(
          a.record.nextServiceDate,
          b.record.nextServiceDate,
        ),
        ServiceSort.highestCost => b.record.serviceCharge.compareTo(
          a.record.serviceCharge,
        ),
      };
    });
    return result;
  }

  bool _matchesFilter(_ServiceEntry entry, DateTime now) {
    final status = entry.record.status;
    return switch (_filter) {
      ServiceFilter.all => true,
      ServiceFilter.active => status.isActive,
      ServiceFilter.scheduled => status == ServiceStatus.scheduled,
      ServiceFilter.completed => status == ServiceStatus.completed,
      ServiceFilter.cancelled => status == ServiceStatus.cancelled,
      ServiceFilter.dueSoon => _isDueSoon(entry, now),
    };
  }

  bool _isDueSoon(_ServiceEntry entry, DateTime now) {
    if (entry.appliance.maintenanceScheduleRecord?.id != entry.record.id) {
      return false;
    }
    final days = entry.record.daysUntilNextService(now);
    return days != null && days >= 0 && days <= 30;
  }

  int _compareNullableDates(DateTime? first, DateTime? second) {
    if (first == null && second == null) return 0;
    if (first == null) return 1;
    if (second == null) return -1;
    return first.compareTo(second);
  }

  Future<void> _addRecord(
    BuildContext context,
    List<Appliance> appliances,
  ) async {
    if (appliances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an appliance before adding service history.'),
        ),
      );
      return;
    }

    final result = await Navigator.of(context).push<ServiceFormResult>(
      MaterialPageRoute(
        builder: (context) => AddServiceRecordScreen(appliances: appliances),
      ),
    );
    if (!context.mounted || result == null) return;
    await _saveResult(context, result);
  }

  Future<void> _editRecord(BuildContext context, _ServiceEntry entry) async {
    final store = AppScope.read(context);
    final result = await Navigator.of(context).push<ServiceFormResult>(
      MaterialPageRoute(
        builder: (context) => AddServiceRecordScreen(
          appliances: store.appliances.toList(growable: false),
          initialApplianceId: entry.appliance.id,
          record: entry.record,
        ),
      ),
    );
    if (!context.mounted || result == null) return;
    await _saveResult(context, result);
  }

  Future<void> _saveResult(
    BuildContext context,
    ServiceFormResult result,
  ) async {
    try {
      final store = AppScope.read(context);
      if (result.isEditing) {
        await store.updateServiceRecord(result.applianceId, result.record);
      } else {
        await store.addServiceRecord(result.applianceId, result.record);
      }

      for (final document in result.documentsToDelete) {
        try {
          await DocumentStorageService().deleteStoredDocument(document);
        } catch (_) {
          // Saved data remains valid even if a stale file cannot be removed.
        }
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isEditing
                ? 'Service record updated.'
                : 'Service record saved.',
          ),
        ),
      );
    } catch (_) {
      for (final document in result.documentsAdded) {
        try {
          await DocumentStorageService().deleteStoredDocument(document);
        } catch (_) {
          // Keep the original save error as the important failure.
        }
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The service record could not be saved. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteRecord(BuildContext context, _ServiceEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete service record?'),
        content: Text(
          'This will remove the service record for ${entry.appliance.name} and its attached receipt/report.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await AppScope.read(
        context,
      ).removeServiceRecord(entry.appliance.id, entry.record.id);
      for (final document in entry.record.documents) {
        try {
          await DocumentStorageService().deleteStoredDocument(document);
        } catch (_) {
          // The record is deleted even if a stale file remains.
        }
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Service record deleted.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The service record could not be deleted.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final entries = _entries(store.appliances);
    final totalCost = store.totalServiceCost;
    final dueSoon = store.upcomingServiceCount(days: 30);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service center'),
        actions: [
          PopupMenuButton<ServiceSort>(
            tooltip: 'Sort service history',
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => ServiceSort.values
                .map(
                  (sort) => PopupMenuItem(value: sort, child: Text(sort.label)),
                )
                .toList(),
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'service_center_add_fab',
        onPressed: () => _addRecord(context, store.appliances),
        icon: const Icon(Icons.add),
        label: const Text('Add service'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Service records',
                        value: '${store.totalServiceRecordCount}',
                        icon: Icons.build_circle_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Due in 30 days',
                        value: '$dueSoon',
                        icon: Icons.event_available_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Total cost',
                        value: totalCost.toStringAsFixed(0),
                        icon: Icons.payments_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search service history',
                    hintText: 'Appliance, provider, ticket or problem',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: ServiceFilter.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = ServiceFilter.values[index];
                      return ChoiceChip(
                        label: Text(filter.label),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? EmptyState(
                    icon: Icons.home_repair_service_outlined,
                    title: store.appliances.isEmpty
                        ? 'Add an appliance first'
                        : 'No matching service records',
                    message: store.appliances.isEmpty
                        ? 'Service history is linked to an appliance.'
                        : 'Add a service record or change the search and filter.',
                    actionLabel: store.appliances.isEmpty
                        ? null
                        : 'Add service record',
                    onAction: store.appliances.isEmpty
                        ? null
                        : () => _addRecord(context, store.appliances),
                  )
                : ListView.builder(
                    key: const Key('serviceCenterList'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ServiceRecordTile(
                        record: entry.record,
                        applianceName: entry.appliance.name,
                        onEdit: () => _editRecord(context, entry),
                        onDelete: () => _deleteRecord(context, entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ServiceEntry {
  const _ServiceEntry({required this.appliance, required this.record});

  final Appliance appliance;
  final ServiceRecord record;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
