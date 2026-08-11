import 'package:flutter/material.dart';

import '../../models/appliance.dart';
import '../../models/homevault_report.dart';
import '../../models/service_record.dart';
import '../../services/homevault_report_service.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../widgets/report_bar.dart';
import '../appliances/appliance_details_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  Future<void> _openAppliance(BuildContext context, String applianceId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ApplianceDetailsScreen(applianceId: applianceId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final report = const HomeVaultReportService().build(store.appliances);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & insights')),
      body: RefreshIndicator(
        onRefresh: store.refresh,
        child: ListView(
          key: const Key('reportsList'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _SectionTitle(
              title: 'Portfolio overview',
              subtitle: 'A live summary of your saved HomeVault records.',
            ),
            const SizedBox(height: 12),
            _MetricsGrid(report: report),
            const SizedBox(height: 16),
            _AttentionCard(report: report),
            const SizedBox(height: 24),
            _SectionCard(
              title: 'Record completeness',
              child: Column(
                children: [
                  ReportBar(
                    label: 'Appliances with documents',
                    value: report.appliancesWithDocuments,
                    total: report.totalAppliances,
                    trailing: _percentage(
                      report.completionRate(report.appliancesWithDocuments),
                    ),
                  ),
                  ReportBar(
                    label: 'Appliances with support details',
                    value: report.appliancesWithSupport,
                    total: report.totalAppliances,
                    trailing: _percentage(
                      report.completionRate(report.appliancesWithSupport),
                    ),
                  ),
                  ReportBar(
                    label: 'Appliances with warranty dates',
                    value: report.appliancesWithWarrantyDate,
                    total: report.totalAppliances,
                    trailing: _percentage(
                      report.completionRate(report.appliancesWithWarrantyDate),
                    ),
                  ),
                  ReportBar(
                    label: 'Appliances with service history',
                    value: report.appliancesWithServiceHistory,
                    total: report.totalAppliances,
                    trailing: _percentage(
                      report.completionRate(
                        report.appliancesWithServiceHistory,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Warranty status',
              child: Column(
                children: WarrantyStatus.values
                    .map((status) {
                      return ReportBar(
                        label: _warrantyLabel(status),
                        value: report.warrantyCount(status),
                        total: report.totalAppliances,
                      );
                    })
                    .toList(growable: false),
              ),
            ),
            if (report.categoryBreakdown.isNotEmpty) ...[
              const SizedBox(height: 16),
              _BreakdownCard(
                title: 'Appliance categories',
                items: report.categoryBreakdown,
                total: report.totalAppliances,
              ),
            ],
            if (report.documentBreakdown.isNotEmpty) ...[
              const SizedBox(height: 16),
              _BreakdownCard(
                title: 'Document categories',
                items: report.documentBreakdown,
                total: report.totalDocuments,
              ),
            ],
            if (report.serviceStatusBreakdown.isNotEmpty) ...[
              const SizedBox(height: 16),
              _BreakdownCard(
                title: 'Service status',
                items: report.serviceStatusBreakdown,
                total: report.totalServiceRecords,
              ),
            ],
            if (report.topMaintenanceCosts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Highest maintenance cost',
                child: Column(
                  children: report.topMaintenanceCosts
                      .map((item) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.payments_outlined),
                          ),
                          title: Text(item.applianceName),
                          subtitle: const Text('Recorded service charges'),
                          trailing: Text(
                            _formatAmount(item.cost),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onTap: () =>
                              _openAppliance(context, item.applianceId),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
            ],
            if (report.upcomingWarranties.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Warranties expiring within 90 days',
                child: Column(
                  children: report.upcomingWarranties
                      .map((item) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.verified_user_outlined),
                          ),
                          title: Text(item.applianceName),
                          subtitle: Text(_formatDate(item.expiryDate)),
                          trailing: Text(_daysText(item.daysRemaining)),
                          onTap: () =>
                              _openAppliance(context, item.applianceId),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
            ],
            if (report.upcomingServices.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Services due within 30 days',
                child: Column(
                  children: report.upcomingServices
                      .map((item) {
                        final provider = item.record.provider.trim();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.build_outlined),
                          ),
                          title: Text(item.applianceName),
                          subtitle: Text(
                            provider.isEmpty
                                ? item.record.status.label
                                : '$provider • ${item.record.status.label}',
                          ),
                          trailing: Text(_daysText(item.daysRemaining)),
                          onTap: () =>
                              _openAppliance(context, item.applianceId),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _percentage(double value) {
    return '${(value * 100).round()}%';
  }

  static String _warrantyLabel(WarrantyStatus status) {
    return switch (status) {
      WarrantyStatus.active => 'Active',
      WarrantyStatus.expiringSoon => 'Expiring soon',
      WarrantyStatus.expired => 'Expired',
      WarrantyStatus.notProvided => 'No expiry date',
    };
  }

  static String _formatAmount(double value) {
    final fixed = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts.first;
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      final remaining = digits.length - index;
      buffer.write(digits[index]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    if (parts.length > 1) {
      buffer.write('.${parts.last}');
    }
    return buffer.toString();
  }

  static String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  static String _daysText(int days) {
    if (days == 0) {
      return 'Today';
    }
    return '$days day${days == 1 ? '' : 's'}';
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.report});

  final HomeVaultReport report;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(
        icon: Icons.devices_other_outlined,
        label: 'Appliances',
        value: '${report.totalAppliances}',
        color: AppColors.primary,
      ),
      _MetricCard(
        icon: Icons.description_outlined,
        label: 'Documents',
        value: '${report.totalDocuments}',
        color: AppColors.warning,
      ),
      _MetricCard(
        icon: Icons.build_circle_outlined,
        label: 'Service records',
        value: '${report.totalServiceRecords}',
        color: AppColors.secondary,
      ),
      _MetricCard(
        icon: Icons.payments_outlined,
        label: 'Service cost',
        value: ReportsScreen._formatAmount(report.totalServiceCost),
        color: AppColors.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 340) {
          return SizedBox(
            height: 92,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < cards.length; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(child: cards[index]),
                ],
              ],
            ),
          );
        }

        final width = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(growable: false),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 92),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              SizedBox(
                height: 24,
                child: Center(
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(height: 1.05),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttentionCard extends StatefulWidget {
  const _AttentionCard({required this.report});

  final HomeVaultReport report;

  @override
  State<_AttentionCard> createState() => _AttentionCardState();
}

class _AttentionCardState extends State<_AttentionCard>
    with AutomaticKeepAliveClientMixin<_AttentionCard> {
  bool _dismissed = false;
  late String _attentionSignature = _signature(widget.report);

  static String _signature(HomeVaultReport report) {
    return [
      report.appliancesWithoutWarrantyDate,
      report.appliancesWithoutDocuments,
      report.appliancesWithoutSupport,
      report.activeServiceRecords,
    ].join(':');
  }

  @override
  void didUpdateWidget(covariant _AttentionCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextSignature = _signature(widget.report);
    if (nextSignature != _attentionSignature) {
      _attentionSignature = nextSignature;
      _dismissed = false;
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final report = widget.report;
    final items = <String>[
      if (report.appliancesWithoutWarrantyDate > 0)
        '${report.appliancesWithoutWarrantyDate} without a warranty date',
      if (report.appliancesWithoutDocuments > 0)
        '${report.appliancesWithoutDocuments} without documents',
      if (report.appliancesWithoutSupport > 0)
        '${report.appliancesWithoutSupport} without support details',
      if (report.activeServiceRecords > 0)
        '${report.activeServiceRecords} active service record${report.activeServiceRecords == 1 ? '' : 's'}',
    ];

    if (_dismissed && items.isNotEmpty) {
      return const SizedBox.shrink();
    }

    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              items.isEmpty
                  ? Icons.task_alt_outlined
                  : Icons.tips_and_updates_outlined,
              color: items.isEmpty ? AppColors.success : AppColors.warning,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    items.isEmpty
                        ? 'Records look complete'
                        : 'Attention needed',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    items.isEmpty
                        ? 'No obvious gaps were found in your current appliance records.'
                        : items.join(' • '),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (items.isEmpty) {
      return card;
    }

    return Dismissible(
      key: ValueKey<String>('reportsAttention-$_attentionSignature'),
      direction: DismissDirection.horizontal,
      resizeDuration: const Duration(milliseconds: 180),
      onDismissed: (_) {
        if (!mounted) return;
        setState(() => _dismissed = true);
      },
      child: card,
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.title,
    required this.items,
    required this.total,
  });

  final String title;
  final List<CountBreakdown> items;
  final int total;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      child: Column(
        children: items
            .map((item) {
              return ReportBar(
                label: item.label,
                value: item.count,
                total: total,
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
