import 'package:flutter/material.dart';

import '../models/service_record.dart';

class ServiceRecordTile extends StatelessWidget {
  const ServiceRecordTile({
    super.key,
    required this.record,
    this.applianceName,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final ServiceRecord record;
  final String? applianceName;
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
    final subtitleLines = <String>[
      if (applianceName != null && applianceName!.trim().isNotEmpty)
        applianceName!,
      if (provider.isNotEmpty) provider,
      if (problem.isNotEmpty) problem,
      'Service date: ${_date(record.serviceDate)}',
      if (record.nextServiceDate != null)
        'Next service: ${_date(record.nextServiceDate!)}',
    ];

    return Card(
      child: ListTile(
        onTap: onTap ?? onEdit,
        isThreeLine: true,
        leading: CircleAvatar(child: Icon(_iconForStatus(record.status))),
        title: Text(
          record.ticketNumber.trim().isEmpty
              ? record.status.label
              : '${record.status.label} • ${record.ticketNumber}',
        ),
        subtitle: Text(
          subtitleLines.join('\n'),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
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
