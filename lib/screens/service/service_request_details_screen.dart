import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/service_form_result.dart';
import '../../models/service_record.dart';
import '../../models/service_request.dart';
import '../../models/service_request_form_result.dart';
import '../../profile/profile_scope.dart';
import '../../services/document_storage_service.dart';
import '../../services/homevault_error_presenter.dart';
import '../../services/support_action_service.dart';
import '../../state/app_scope.dart';
import 'add_service_record_screen.dart';
import 'add_service_request_screen.dart';

class ServiceRequestDetailsScreen extends StatelessWidget {
  const ServiceRequestDetailsScreen({
    super.key,
    required this.applianceId,
    required this.requestId,
  });

  final String applianceId;
  final String requestId;

  String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _dateTime(DateTime value) {
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${_date(value)} • $hour:$minute $period';
  }

  Future<void> _edit(BuildContext context, ServiceRequest request) async {
    final store = AppScope.read(context);
    final appliance = store.applianceById(applianceId);
    if (appliance == null) return;

    final result = await Navigator.of(context).push<ServiceRequestFormResult>(
      MaterialPageRoute(
        builder: (context) => AddServiceRequestScreen(
          appliances: store.appliances.toList(growable: false),
          initialApplianceId: applianceId,
          request: request,
          initialProfile: ProfileScope.of(context).profile,
        ),
      ),
    );
    if (!context.mounted || result == null) return;

    try {
      await store.updateServiceRequest(result.applianceId, result.request);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Service request updated.')));
    } catch (error) {
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The service request could not be updated. Please try again.',
      );
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    ServiceRequest request,
  ) async {
    final options = request.status.nextStatuses;
    if (options.isEmpty) return;

    final nextStatus = await showModalBottomSheet<ServiceRequestStatus>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Update request status',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text('Current status: ${request.status.label}'),
              const SizedBox(height: 12),
              for (final status in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_statusIcon(status)),
                  title: Text(status.label),
                  onTap: () => Navigator.of(context).pop(status),
                ),
            ],
          ),
        ),
      ),
    );
    if (nextStatus == null || !context.mounted) return;

    final updated = request.withStatus(nextStatus, changedAt: DateTime.now());

    try {
      await AppScope.read(context).updateServiceRequest(applianceId, updated);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request marked ${nextStatus.label}.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The request status could not be updated. Please try again.',
      );
    }
  }

  Future<void> _delete(BuildContext context, ServiceRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete service request?'),
        content: Text(
          request.linkedServiceRecordId.isEmpty
              ? 'This removes the request and its status history.'
              : 'This removes the request and its status history. The linked service record will remain in service history.',
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
      ).removeServiceRequest(applianceId, request.id);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Service request deleted.')));
    } catch (error) {
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The service request could not be deleted. Please try again.',
      );
    }
  }

  Future<void> _callProvider(
    BuildContext context,
    ServiceRequest request,
  ) async {
    try {
      await const SupportActionService().call(request.providerPhone);
    } catch (error) {
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The provider could not be called from this device.',
      );
    }
  }

  Future<void> _copySummary(
    BuildContext context,
    String applianceName,
    ServiceRequest request,
  ) async {
    final lines = <String>[
      'HomeVault service request',
      'Appliance: $applianceName',
      'Status: ${request.status.label}',
      'Preferred date: ${_date(request.preferredDate)}',
      'Preferred time: ${request.visitWindow.label} (${request.visitWindow.timeLabel})',
      'Issue: ${request.issueDescription}',
      'Address: ${request.serviceAddress.replaceAll('\n', ', ')}',
      if (request.contactName.trim().isNotEmpty)
        'Contact: ${request.contactName.trim()}',
      if (request.contactPhone.trim().isNotEmpty)
        'Contact phone: ${request.contactPhone.trim()}',
      if (request.provider.trim().isNotEmpty)
        'Provider: ${request.provider.trim()}',
      if (request.ticketNumber.trim().isNotEmpty)
        'Ticket: ${request.ticketNumber.trim()}',
    ];

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Service request details copied.')),
    );
  }

  Future<void> _addServiceRecord(
    BuildContext context,
    ServiceRequest request,
  ) async {
    final store = AppScope.read(context);
    final result = await Navigator.of(context).push<ServiceFormResult>(
      MaterialPageRoute(
        builder: (context) => AddServiceRecordScreen(
          appliances: store.appliances.toList(growable: false),
          initialApplianceId: applianceId,
          initialServiceDate: request.preferredDate,
          initialProvider: request.provider,
          initialTechnicianName: request.technicianName,
          initialTicketNumber: request.ticketNumber,
          initialProblemDescription: request.issueDescription,
        ),
      ),
    );
    if (!context.mounted || result == null) return;

    try {
      await store.addServiceRecord(result.applianceId, result.record);
    } catch (error) {
      for (final document in result.documentsAdded) {
        try {
          await DocumentStorageService().deleteStoredDocument(document);
        } catch (_) {
          // Preserve the service-record save error.
        }
      }
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The service record could not be saved. Please try again.',
      );
      return;
    }

    final now = DateTime.now();
    var updatedRequest = request.copyWith(
      updatedAt: now,
      linkedServiceRecordId: result.record.id,
    );
    if (updatedRequest.status.isActive &&
        result.record.status == ServiceStatus.completed) {
      updatedRequest = updatedRequest.withStatus(
        ServiceRequestStatus.completed,
        changedAt: now,
        note: 'Completed service record added.',
      );
    }

    try {
      await store.updateServiceRequest(applianceId, updatedRequest);
    } catch (error) {
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback:
            'The service record was saved, but the request could not be linked to it.',
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Service record saved and linked.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final appliance = store.applianceById(applianceId);
    final request = appliance?.serviceRequestById(requestId);

    if (appliance == null || request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Service request')),
        body: const Center(child: Text('This service request is unavailable.')),
      );
    }

    final history = [...request.statusHistory]
      ..sort((a, b) => b.changedAt.compareTo(a.changedAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service request'),
        actions: [
          if (request.status.isActive)
            IconButton(
              tooltip: 'Edit request',
              onPressed: () => _edit(context, request),
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            tooltip: 'Delete request',
            onPressed: () => _delete(context, request),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          appliance.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      _StatusChip(status: request.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    request.issueDescription,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        key: const Key('updateServiceRequestStatusButton'),
                        onPressed: request.status.nextStatuses.isEmpty
                            ? null
                            : () => _updateStatus(context, request),
                        icon: const Icon(Icons.sync_alt_outlined),
                        label: const Text('Update status'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _copySummary(context, appliance.name, request),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy details'),
                      ),
                      if (request.providerPhone.trim().isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => _callProvider(context, request),
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('Call provider'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Preferred visit',
            children: [
              _DetailRow(label: 'Date', value: _date(request.preferredDate)),
              _DetailRow(
                label: 'Time',
                value:
                    '${request.visitWindow.label} • ${request.visitWindow.timeLabel}',
              ),
              _DetailRow(label: 'Address', value: request.serviceAddress),
              if (request.contactName.trim().isNotEmpty)
                _DetailRow(label: 'Contact', value: request.contactName),
              if (request.contactPhone.trim().isNotEmpty)
                _DetailRow(label: 'Mobile', value: request.contactPhone),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Provider',
            children: [
              _DetailRow(label: 'Provider', value: request.provider),
              _DetailRow(label: 'Phone', value: request.providerPhone),
              _DetailRow(label: 'Ticket', value: request.ticketNumber),
              _DetailRow(label: 'Technician', value: request.technicianName),
              if (request.notes.trim().isNotEmpty)
                _DetailRow(label: 'Notes', value: request.notes),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Service history link',
            children: [
              if (request.linkedServiceRecordId.isEmpty) ...[
                const Text(
                  'After the visit, add the completed work to service history. HomeVault will link the record to this request.',
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const Key('addRecordFromServiceRequestButton'),
                    onPressed: () => _addServiceRecord(context, request),
                    icon: const Icon(Icons.build_circle_outlined),
                    label: const Text('Add service record'),
                  ),
                ),
              ] else
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.link_outlined),
                  title: Text('Service record linked'),
                  subtitle: Text(
                    'The completed visit is also saved in service history.',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Status history',
            children: [
              for (var index = 0; index < history.length; index++) ...[
                if (index > 0) const Divider(height: 18),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_statusIcon(history[index].status)),
                  title: Text(history[index].status.label),
                  subtitle: Text(
                    [
                      _dateTime(history[index].changedAt),
                      if (history[index].note.trim().isNotEmpty)
                        history[index].note.trim(),
                    ].join('\n'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

IconData _statusIcon(ServiceRequestStatus status) => switch (status) {
  ServiceRequestStatus.requested => Icons.outbox_outlined,
  ServiceRequestStatus.confirmed => Icons.event_available_outlined,
  ServiceRequestStatus.technicianAssigned => Icons.engineering_outlined,
  ServiceRequestStatus.inProgress => Icons.handyman_outlined,
  ServiceRequestStatus.completed => Icons.check_circle_outline,
  ServiceRequestStatus.cancelled => Icons.cancel_outlined,
};

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ServiceRequestStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(_statusIcon(status), size: 17),
      label: Text(status.label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final shownValue = value.trim().isEmpty ? 'Not provided' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(shownValue)),
        ],
      ),
    );
  }
}
