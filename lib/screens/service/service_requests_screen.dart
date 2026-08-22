import 'package:flutter/material.dart';

import '../../models/appliance.dart';
import '../../models/service_request.dart';
import '../../models/service_request_form_result.dart';
import '../../profile/profile_scope.dart';
import '../../services/homevault_error_presenter.dart';
import '../../state/app_scope.dart';
import '../../widgets/empty_state.dart';
import 'add_service_request_screen.dart';
import 'service_request_details_screen.dart';

enum ServiceRequestFilter {
  all,
  active,
  requested,
  confirmed,
  inProgress,
  completed,
  cancelled,
}

extension ServiceRequestFilterLabel on ServiceRequestFilter {
  String get label => switch (this) {
    ServiceRequestFilter.all => 'All',
    ServiceRequestFilter.active => 'Active',
    ServiceRequestFilter.requested => 'Requested',
    ServiceRequestFilter.confirmed => 'Confirmed',
    ServiceRequestFilter.inProgress => 'In progress',
    ServiceRequestFilter.completed => 'Completed',
    ServiceRequestFilter.cancelled => 'Cancelled',
  };
}

class ServiceRequestsScreen extends StatefulWidget {
  const ServiceRequestsScreen({super.key, this.initialApplianceId, this.now});

  final String? initialApplianceId;
  final DateTime? now;

  @override
  State<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends State<ServiceRequestsScreen> {
  final _searchController = TextEditingController();
  ServiceRequestFilter _filter = ServiceRequestFilter.all;

  @override
  void initState() {
    super.initState();
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

  List<_RequestEntry> _entries(List<Appliance> appliances) {
    final query = _searchController.text.trim().toLowerCase();
    final result = <_RequestEntry>[];

    for (final appliance in appliances) {
      for (final request in appliance.serviceRequests) {
        if (!_matchesFilter(request)) continue;

        if (query.isNotEmpty) {
          final searchable = [
            appliance.name,
            appliance.brand,
            request.issueDescription,
            request.provider,
            request.providerPhone,
            request.ticketNumber,
            request.technicianName,
            request.serviceAddress,
            request.status.label,
          ].join(' ').toLowerCase();
          if (!searchable.contains(query)) continue;
        }

        result.add(_RequestEntry(appliance: appliance, request: request));
      }
    }

    result.sort((first, second) {
      final priority = first.request.status.sortPriority.compareTo(
        second.request.status.sortPriority,
      );
      if (priority != 0) return priority;

      if (first.request.status.isActive && second.request.status.isActive) {
        return first.request.preferredDate.compareTo(
          second.request.preferredDate,
        );
      }
      return second.request.updatedAt.compareTo(first.request.updatedAt);
    });

    return result;
  }

  bool _matchesFilter(ServiceRequest request) => switch (_filter) {
    ServiceRequestFilter.all => true,
    ServiceRequestFilter.active => request.status.isActive,
    ServiceRequestFilter.requested =>
      request.status == ServiceRequestStatus.requested,
    ServiceRequestFilter.confirmed =>
      request.status == ServiceRequestStatus.confirmed ||
          request.status == ServiceRequestStatus.technicianAssigned,
    ServiceRequestFilter.inProgress =>
      request.status == ServiceRequestStatus.inProgress,
    ServiceRequestFilter.completed =>
      request.status == ServiceRequestStatus.completed,
    ServiceRequestFilter.cancelled =>
      request.status == ServiceRequestStatus.cancelled,
  };

  Future<void> _createRequest(BuildContext context) async {
    final store = AppScope.read(context);
    if (store.appliances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an appliance before requesting service.'),
        ),
      );
      return;
    }

    final result = await Navigator.of(context).push<ServiceRequestFormResult>(
      MaterialPageRoute(
        builder: (context) => AddServiceRequestScreen(
          appliances: store.appliances.toList(growable: false),
          initialApplianceId: widget.initialApplianceId,
          initialProfile: ProfileScope.of(context).profile,
        ),
      ),
    );
    if (!context.mounted || result == null) return;

    try {
      await store.addServiceRequest(result.applianceId, result.request);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Service request saved.')));
    } catch (error) {
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The service request could not be saved. Please try again.',
      );
    }
  }

  Future<void> _openRequest(BuildContext context, _RequestEntry entry) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ServiceRequestDetailsScreen(
          applianceId: entry.appliance.id,
          requestId: entry.request.id,
        ),
      ),
    );
  }

  String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _dateContext(ServiceRequest request) {
    final days = request.daysUntilPreferredDate(widget.now ?? DateTime.now());
    if (days < 0) return '${days.abs()} day${days == -1 ? '' : 's'} ago';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return '$days days';
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final entries = _entries(store.appliances);
    final allRequests = store.appliances
        .expand((appliance) => appliance.serviceRequests)
        .toList(growable: false);
    final active = allRequests
        .where((request) => request.status.isActive)
        .length;
    final today = widget.now ?? DateTime.now();
    final upcoming = allRequests.where((request) {
      if (!request.status.isActive) return false;
      final days = request.daysUntilPreferredDate(today);
      return days >= 0 && days <= 7;
    }).length;
    final completed = allRequests
        .where((request) => request.status == ServiceRequestStatus.completed)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Service requests')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('newServiceRequestFab'),
        heroTag: 'service_requests_add_fab',
        onPressed: store.appliances.isEmpty
            ? null
            : () => _createRequest(context),
        icon: const Icon(Icons.add_task_outlined),
        label: const Text('Request service'),
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
                        label: 'Active',
                        value: '$active',
                        icon: Icons.pending_actions_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Next 7 days',
                        value: '$upcoming',
                        icon: Icons.calendar_today_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Completed',
                        value: '$completed',
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search service requests',
                    hintText: 'Appliance, provider, ticket or issue',
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
                        index < ServiceRequestFilter.values.length;
                        index++
                      ) ...[
                        if (index > 0) const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(ServiceRequestFilter.values[index].label),
                          selected:
                              _filter == ServiceRequestFilter.values[index],
                          onSelected: (_) => setState(
                            () => _filter = ServiceRequestFilter.values[index],
                          ),
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
                    icon: Icons.calendar_month_outlined,
                    title: store.appliances.isEmpty
                        ? 'Add an appliance first'
                        : allRequests.isEmpty
                        ? 'No service requests yet'
                        : 'No matching requests',
                    message: store.appliances.isEmpty
                        ? 'Service requests are linked to an appliance.'
                        : allRequests.isEmpty
                        ? 'Create a request to save the preferred visit, address and provider status.'
                        : 'No requests match the current search or filter.',
                    actionLabel: store.appliances.isEmpty
                        ? null
                        : allRequests.isEmpty
                        ? 'Request service'
                        : 'Show all requests',
                    onAction: store.appliances.isEmpty
                        ? null
                        : allRequests.isEmpty
                        ? () => _createRequest(context)
                        : () async {
                            _searchController.clear();
                            setState(() => _filter = ServiceRequestFilter.all);
                          },
                  )
                : ListView.separated(
                    key: const Key('serviceRequestsList'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final request = entry.request;
                      return Card(
                        key: ValueKey('serviceRequest-${request.id}'),
                        margin: EdgeInsets.zero,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openRequest(context, entry),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.appliance.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Chip(
                                      label: Text(request.status.label),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  request.issueDescription,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.event_outlined, size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${_date(request.preferredDate)} • ${request.visitWindow.label}',
                                      ),
                                    ),
                                    Text(
                                      _dateContext(request),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                  ],
                                ),
                                if (request.provider.trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.business_outlined,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          request.provider,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RequestEntry {
  const _RequestEntry({required this.appliance, required this.request});

  final Appliance appliance;
  final ServiceRequest request;
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
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
