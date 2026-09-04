import 'package:flutter/material.dart';

import '../accessibility/homevault_accessibility.dart';
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
    final workCompleted = record.workCompleted.trim();
    final partsReplaced = record.partsReplaced.trim();
    final appliance = applianceName?.trim() ?? '';
    final ticket = record.ticketNumber.trim();
    final effectiveStatus = record.effectiveStatus(now ?? DateTime.now());
    final title = ticket.isEmpty
        ? effectiveStatus.label
        : '${effectiveStatus.label} • $ticket';

    final serviceDateContext = effectiveStatus == ServiceStatus.completed
        ? 'serviced ${_spokenDate(record.serviceDate)}'
        : 'service ${_spokenDate(record.serviceDate)}';
    final recordContext = [
      if (appliance.isNotEmpty) appliance,
      serviceDateContext,
      if (ticket.isNotEmpty) 'ticket $ticket',
    ].join(', ');

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
              ExcludeSemantics(
                child: CircleAvatar(
                  child: Icon(_iconForStatus(effectiveStatus)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (appliance.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        appliance,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (provider.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _DetailLine(
                        icon: Icons.storefront_outlined,
                        label: 'Provider',
                        value: provider,
                      ),
                    ],
                    if (problem.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _DetailLine(
                        icon: Icons.report_problem_outlined,
                        label: 'Issue',
                        value: problem,
                      ),
                    ],
                    if (workCompleted.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _DetailLine(
                        icon: Icons.handyman_outlined,
                        label: 'Work done',
                        value: workCompleted,
                      ),
                    ],
                    if (partsReplaced.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _DetailLine(
                        icon: Icons.settings_suggest_outlined,
                        label: 'Parts',
                        value: partsReplaced,
                      ),
                    ],
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CompactLabel(
                          icon: Icons.event_outlined,
                          text: effectiveStatus == ServiceStatus.completed
                              ? 'Last serviced ${_date(record.serviceDate)}'
                              : 'Service ${_date(record.serviceDate)}',
                        ),
                        if (record.serviceFrequencyLabel != null)
                          _CompactLabel(
                            icon: Icons.autorenew_outlined,
                            text: record.serviceFrequencyLabel!,
                          ),
                        if (record.nextServiceDate != null)
                          _CompactLabel(
                            icon: Icons.event_repeat_outlined,
                            text: 'Next ${_date(record.nextServiceDate!)}',
                          ),
                        if (record.serviceCharge > 0)
                          _CompactLabel(
                            icon: Icons.currency_rupee,
                            text:
                                '${_formatIndianCurrency(record.serviceCharge)}/-',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  tooltip: HomeVaultAccessibility.contextualAction(
                    'Service record actions',
                    recordContext,
                  ),
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      PopupMenuItem(
                        value: 'edit',
                        child: Semantics(
                          label: 'Edit service record for $recordContext',
                          excludeSemantics: true,
                          child: const ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Edit'),
                          ),
                        ),
                      ),
                    if (onDelete != null)
                      PopupMenuItem(
                        value: 'delete',
                        child: Semantics(
                          label: 'Delete service record for $recordContext',
                          excludeSemantics: true,
                          child: const ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline),
                            title: Text('Delete'),
                          ),
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

  String _spokenDate(DateTime value) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactLabel extends StatelessWidget {
  const _CompactLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(text, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
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
