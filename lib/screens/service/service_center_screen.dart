import 'package:flutter/material.dart';

import '../../models/appliance.dart';
import '../../models/service_form_result.dart';
import '../../models/service_record.dart';
import '../../services/document_storage_service.dart';
import '../../services/homevault_error_presenter.dart';
import '../../state/app_scope.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/service_record_tile.dart';
import 'add_service_record_screen.dart';

enum ServiceFilter { all, open, scheduled, dueSoon, completed, cancelled }

enum ServiceSort { statusPriority, newest, oldest, nextService, highestCost }

extension ServiceFilterLabel on ServiceFilter {
  String get label => switch (this) {
    ServiceFilter.all => 'All',
    ServiceFilter.open => 'Open',
    ServiceFilter.scheduled => 'Scheduled',
    ServiceFilter.dueSoon => 'Due soon',
    ServiceFilter.completed => 'Completed',
    ServiceFilter.cancelled => 'Cancelled',
  };
}

extension ServiceSortLabel on ServiceSort {
  String get label => switch (this) {
    ServiceSort.statusPriority => 'Service status',
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
    this.now,
  });

  final ServiceFilter initialFilter;
  final DateTime? now;

  @override
  State<ServiceCenterScreen> createState() => _ServiceCenterScreenState();
}

class _ServiceCenterScreenState extends State<ServiceCenterScreen> {
  static const _filterOrder = <ServiceFilter>[
    ServiceFilter.all,
    ServiceFilter.open,
    ServiceFilter.scheduled,
    ServiceFilter.dueSoon,
    ServiceFilter.completed,
    ServiceFilter.cancelled,
  ];

  final _searchController = TextEditingController();
  late ServiceFilter _filter;
  ServiceSort _sort = ServiceSort.statusPriority;
  bool _resolvedInitialDueSoonFilter = false;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _searchController.addListener(_refresh);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedInitialDueSoonFilter) return;
    _resolvedInitialDueSoonFilter = true;

    // The dashboard's "Service due" metric opens this screen with the
    // Due-soon filter. If there is nothing due, showing an empty Service
    // Center is misleading when service history already exists. Fall back to
    // All so the user's records are visible immediately.
    if (_filter == ServiceFilter.dueSoon) {
      final store = AppScope.of(context);
      if (store.totalServiceRecordCount > 0 &&
          store.upcomingServiceCount(days: 30) == 0) {
        _filter = ServiceFilter.all;
      }
    }
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
    final now = widget.now ?? DateTime.now();
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
            record.effectiveStatus(now).label,
          ].join(' ').toLowerCase();
          if (!searchable.contains(query)) continue;
        }
        result.add(entry);
      }
    }

    result.sort((a, b) {
      return switch (_sort) {
        ServiceSort.statusPriority => _compareByStatusPriority(a, b, now),
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
    final status = entry.record.effectiveStatus(now);
    return switch (_filter) {
      ServiceFilter.all => true,
      ServiceFilter.open =>
        status == ServiceStatus.open || status == ServiceStatus.inProgress,
      ServiceFilter.scheduled => status == ServiceStatus.scheduled,
      ServiceFilter.dueSoon => _isDueSoon(entry, now),
      ServiceFilter.completed => status == ServiceStatus.completed,
      ServiceFilter.cancelled => status == ServiceStatus.cancelled,
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

  int _compareByStatusPriority(
    _ServiceEntry first,
    _ServiceEntry second,
    DateTime now,
  ) {
    final firstPriority = _statusPriority(first, now);
    final secondPriority = _statusPriority(second, now);

    final priorityComparison = firstPriority.compareTo(secondPriority);
    if (priorityComparison != 0) return priorityComparison;

    // Within the actionable groups, show the earliest service/due date first.
    if (firstPriority == 0 || firstPriority == 1) {
      return first.record.serviceDate.compareTo(second.record.serviceDate);
    }
    if (firstPriority == 2) {
      return _compareNullableDates(
        first.record.nextServiceDate,
        second.record.nextServiceDate,
      );
    }

    // For completed/cancelled history, keep the most recent record first.
    return second.record.serviceDate.compareTo(first.record.serviceDate);
  }

  int _statusPriority(_ServiceEntry entry, DateTime now) {
    final status = entry.record.effectiveStatus(now);

    if (status == ServiceStatus.open || status == ServiceStatus.inProgress) {
      return 0;
    }
    if (status == ServiceStatus.scheduled) {
      return 1;
    }
    if (_isDueSoon(entry, now)) {
      return 2;
    }
    if (status == ServiceStatus.completed) {
      return 3;
    }
    if (status == ServiceStatus.cancelled) {
      return 4;
    }
    return 3;
  }

  Future<void> _showAllRecords() async {
    _searchController.clear();
    if (!mounted) return;
    setState(() => _filter = ServiceFilter.all);
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
    } catch (error) {
      for (final document in result.documentsAdded) {
        try {
          await DocumentStorageService().deleteStoredDocument(document);
        } catch (_) {
          // Keep the original save error as the important failure.
        }
      }
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The service record could not be saved. Please try again.',
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
    } catch (error) {
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The service record could not be deleted. Please try again.',
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
                        label: 'Records',
                        value: '${store.totalServiceRecordCount}',
                        icon: Icons.build_circle_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Due 30 days',
                        value: '$dueSoon',
                        icon: Icons.event_available_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Total cost',
                        value: '${_formatIndianCurrency(totalCost)}/-',
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (
                        var index = 0;
                        index < _filterOrder.length;
                        index++
                      ) ...[
                        if (index > 0) const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(_filterOrder[index].label),
                          selected: _filter == _filterOrder[index],
                          onSelected: (_) =>
                              setState(() => _filter = _filterOrder[index]),
                        ),
                      ],
                    ],
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
                        : (_filter != ServiceFilter.all ||
                              _searchController.text.trim().isNotEmpty)
                        ? 'No records match the current search or filter.'
                        : 'Add a service record to start building service history.',
                    actionLabel: store.appliances.isEmpty
                        ? null
                        : (_filter != ServiceFilter.all ||
                              _searchController.text.trim().isNotEmpty)
                        ? 'Show all service records'
                        : 'Add service record',
                    onAction: store.appliances.isEmpty
                        ? null
                        : (_filter != ServiceFilter.all ||
                              _searchController.text.trim().isNotEmpty)
                        ? _showAllRecords
                        : () => _addRecord(context, store.appliances),
                  )
                : ListView.separated(
                    key: const Key('serviceCenterList'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ServiceRecordTile(
                        key: ValueKey('serviceRecord-${entry.record.id}'),
                        record: entry.record,
                        applianceName: entry.appliance.name,
                        now: widget.now,
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

String _formatIndianCurrency(double value) {
  final rounded = value.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  if (digits.length <= 3) {
    return '${negative ? '-' : ''}₹$digits';
  }

  final lastThree = digits.substring(digits.length - 3);
  var leading = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (leading.length > 2) {
    groups.insert(0, leading.substring(leading.length - 2));
    leading = leading.substring(0, leading.length - 2);
  }
  if (leading.isNotEmpty) groups.insert(0, leading);

  return '${negative ? '-' : ''}₹${groups.join(',')},$lastThree';
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            SizedBox(
              height: 24,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
