import 'package:flutter/material.dart';

import '../models/service_record.dart';

class ServiceRecordTile extends StatelessWidget {
  const ServiceRecordTile({
    super.key,
    required this.record,
    this.applianceName,
    this.now,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final ServiceRecord record;
  final String? applianceName;
  final DateTime? now;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = record.provider.trim();
    final problem = record.problemDescription.trim();
    final appliance = applianceName?.trim() ?? '';
    final effectiveStatus = record.effectiveStatus(now ?? DateTime.now());
    final title = record.ticketNumber.trim().isEmpty
        ? effectiveStatus.label
        : '${effectiveStatus.label} • ${record.ticketNumber.trim()}';

    final details = <String>[
      if (provider.isNotEmpty) 'Provider: $provider',
      if (problem.isNotEmpty) 'Issue: $problem',
      effectiveStatus == ServiceStatus.completed
          ? 'Last serviced: ${_date(record.serviceDate)}'
          : 'Service date: ${_date(record.serviceDate)}',
      if (record.serviceFrequencyLabel != null)
        'Service frequency: ${record.serviceFrequencyLabel}',
      if (record.nextServiceDate != null)
        'Next service: ${_date(record.nextServiceDate!)}',
    ];

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(child: Icon(_iconForStatus(effectiveStatus))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (appliance.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        appliance,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      for (var index = 0; index < details.length; index++) ...[
                        Text(
                          details[index],
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (index != details.length - 1)
                          const SizedBox(height: 2),
                      ],
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Service record options',
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForStatus(ServiceStatus status) {
    return switch (status) {
      ServiceStatus.scheduled => Icons.event_available_outlined,
      ServiceStatus.open => Icons.report_problem_outlined,
      ServiceStatus.inProgress => Icons.engineering_outlined,
      ServiceStatus.completed => Icons.task_alt_outlined,
      ServiceStatus.cancelled => Icons.cancel_outlined,
    };
  }
}
