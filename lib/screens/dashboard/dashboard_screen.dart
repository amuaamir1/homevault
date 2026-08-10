import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/appliance.dart';
import '../../models/homevault_report.dart';
import '../../profile/profile_scope.dart';
import '../../services/homevault_report_service.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../widgets/warranty_status_chip.dart';
import '../service/service_center_screen.dart';
import '../warranty/warranty_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onAddAppliance,
    required this.onOpenAppliances,
    required this.onOpenDocuments,
    required this.onOpenWarrantyCenter,
    required this.onOpenServiceCenter,
    required this.onOpenGlobalSearch,
    required this.onOpenReports,
    required this.onOpenAppliance,
  });

  final Future<void> Function() onAddAppliance;
  final Future<void> Function() onOpenAppliances;
  final Future<void> Function() onOpenDocuments;
  final Future<void> Function(WarrantyFilter initialFilter)
  onOpenWarrantyCenter;
  final Future<void> Function(ServiceFilter initialFilter) onOpenServiceCenter;
  final Future<void> Function() onOpenGlobalSearch;
  final Future<void> Function() onOpenReports;
  final Future<void> Function(String applianceId) onOpenAppliance;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final profile = ProfileScope.of(context).profile;
    final firstName = profile?.firstName ?? '';
    final recentAppliances = store.recentAppliances;
    final report = const HomeVaultReportService().build(store.appliances);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HomeVault',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Add appliance',
            onPressed: onAddAppliance,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Search HomeVault',
            onPressed: onOpenGlobalSearch,
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: ScrollConfiguration(
        key: const ValueKey('dashboardNoStretchScrollConfiguration'),
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: RefreshIndicator(
          onRefresh: store.refresh,
          child: SingleChildScrollView(
            key: const Key('dashboardScrollView'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DashboardHeader(firstName: firstName),
                if (store.loadWarning != null) ...[
                  const SizedBox(height: 14),
                  MaterialBanner(
                    content: Text(store.loadWarning!),
                    leading: const Icon(Icons.warning_amber_outlined),
                    actions: [
                      TextButton(
                        onPressed: store.clearLoadWarning,
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                _SectionTitle(
                  title: 'At a glance',
                  subtitle: 'A quick summary of your HomeVault.',
                  actionLabel: 'Reports',
                  onAction: onOpenReports,
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    _MetricCard(
                      key: const ValueKey('dashboardApplianceMetric'),
                      icon: Icons.home_repair_service_outlined,
                      label: 'Appliances',
                      value: '${report.totalAppliances}',
                      color: AppColors.primary,
                      onTap: onOpenAppliances,
                    ),
                    _MetricCard(
                      key: const ValueKey('dashboardDocumentMetric'),
                      icon: Icons.description_outlined,
                      label: 'Documents',
                      value: '${report.totalDocuments}',
                      color: AppColors.warning,
                      onTap: onOpenDocuments,
                    ),
                    _MetricCard(
                      key: const ValueKey('dashboardActiveWarrantyMetric'),
                      icon: Icons.verified_user_outlined,
                      label: 'Active warranty',
                      value: '${report.warrantyCount(WarrantyStatus.active)}',
                      color: AppColors.success,
                      onTap: () => onOpenWarrantyCenter(WarrantyFilter.active),
                    ),
                    _MetricCard(
                      key: const ValueKey('dashboardServiceDueMetric'),
                      icon: Icons.event_available_outlined,
                      label: 'Service due',
                      value: '${report.upcomingServices.length}',
                      color: AppColors.secondary,
                      onTap: () => onOpenServiceCenter(ServiceFilter.dueSoon),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _SectionTitle(
                  title: 'Warranty overview',
                  subtitle:
                      'See which appliances are covered or need attention.',
                  actionLabel: 'View all',
                  onAction: () => onOpenWarrantyCenter(WarrantyFilter.all),
                ),
                const SizedBox(height: 12),
                _WarrantyOverview(
                  report: report,
                  onOpenWarrantyCenter: onOpenWarrantyCenter,
                ),
                const SizedBox(height: 28),
                _SectionTitle(
                  title: 'Coming up',
                  subtitle: 'Upcoming warranty expiries and service dates.',
                ),
                const SizedBox(height: 12),
                _UpcomingActions(
                  report: report,
                  onOpenAppliance: onOpenAppliance,
                  onOpenWarrantyCenter: onOpenWarrantyCenter,
                  onOpenServiceCenter: onOpenServiceCenter,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent appliances',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (recentAppliances.isNotEmpty)
                      TextButton(
                        onPressed: onOpenAppliances,
                        child: const Text('View all'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (recentAppliances.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 40),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'No appliances added yet. Add your first appliance to begin.',
                            ),
                          ),
                          IconButton(
                            tooltip: 'Add appliance',
                            onPressed: onAddAppliance,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...recentAppliances.map(
                    (appliance) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          leading: _DashboardAppliancePhoto(
                            appliance: appliance,
                          ),
                          title: Text(appliance.name),
                          subtitle: Text(
                            appliance.brand.isEmpty
                                ? appliance.category
                                : '${appliance.brand} \u2022 ${appliance.category}',
                          ),
                          trailing: WarrantyStatusChip(
                            status: appliance.warrantyStatusAt(DateTime.now()),
                          ),
                          onTap: () => onOpenAppliance(appliance.id),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardAppliancePhoto extends StatelessWidget {
  const _DashboardAppliancePhoto({required this.appliance});

  final Appliance appliance;

  @override
  Widget build(BuildContext context) {
    final path = appliance.appliancePhotoDocument?.localPath.trim() ?? '';
    if (path.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.devices_other));
    }

    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ClipOval(
        child: Image.file(
          File(path),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.devices_other),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstName.isEmpty ? 'Welcome home' : 'Welcome $firstName',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep warranties, documents, support details, and maintenance organised in one place.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarrantyOverview extends StatelessWidget {
  const _WarrantyOverview({
    required this.report,
    required this.onOpenWarrantyCenter,
  });

  final HomeVaultReport report;
  final Future<void> Function(WarrantyFilter initialFilter)
  onOpenWarrantyCenter;

  @override
  Widget build(BuildContext context) {
    final items = [
      _WarrantyOverviewItem(
        label: 'Active',
        value: report.warrantyCount(WarrantyStatus.active),
        color: AppColors.success,
        icon: Icons.check_circle_outline,
        filter: WarrantyFilter.active,
      ),
      _WarrantyOverviewItem(
        label: 'Expiring',
        value: report.warrantyCount(WarrantyStatus.expiringSoon),
        color: AppColors.warning,
        icon: Icons.schedule_outlined,
        filter: WarrantyFilter.expiringSoon,
      ),
      _WarrantyOverviewItem(
        label: 'Expired',
        value: report.warrantyCount(WarrantyStatus.expired),
        color: AppColors.danger,
        icon: Icons.cancel_outlined,
        filter: WarrantyFilter.expired,
      ),
      _WarrantyOverviewItem(
        label: 'Not added',
        value: report.warrantyCount(WarrantyStatus.notProvided),
        color: AppColors.textSecondary,
        icon: Icons.help_outline,
        filter: WarrantyFilter.notProvided,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: items[index].color.withValues(alpha: 0.12),
                  foregroundColor: items[index].color,
                  child: Icon(items[index].icon, size: 20),
                ),
                title: Text(
                  items[index].label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${items[index].value}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => onOpenWarrantyCenter(items[index].filter),
              ),
              if (index != items.length - 1)
                const Divider(height: 1, indent: 72),
            ],
          ],
        ),
      ),
    );
  }
}

class _WarrantyOverviewItem {
  const _WarrantyOverviewItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.filter,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final WarrantyFilter filter;
}

class _UpcomingActions extends StatelessWidget {
  const _UpcomingActions({
    required this.report,
    required this.onOpenAppliance,
    required this.onOpenWarrantyCenter,
    required this.onOpenServiceCenter,
  });

  final HomeVaultReport report;
  final Future<void> Function(String applianceId) onOpenAppliance;
  final Future<void> Function(WarrantyFilter initialFilter)
  onOpenWarrantyCenter;
  final Future<void> Function(ServiceFilter initialFilter) onOpenServiceCenter;

  @override
  Widget build(BuildContext context) {
    final items = <_UpcomingItem>[
      ...report.upcomingWarranties.map(
        (item) => _UpcomingItem(
          applianceId: item.applianceId,
          title: item.applianceName,
          subtitle: 'Warranty expires ${_relativeDayLabel(item.daysRemaining)}',
          daysRemaining: item.daysRemaining,
          icon: Icons.verified_user_outlined,
          color: item.daysRemaining <= 30
              ? AppColors.warning
              : AppColors.primary,
        ),
      ),
      ...report.upcomingServices.map(
        (item) => _UpcomingItem(
          applianceId: item.applianceId,
          title: item.applianceName,
          subtitle: 'Service due ${_relativeDayLabel(item.daysRemaining)}',
          daysRemaining: item.daysRemaining,
          icon: Icons.build_circle_outlined,
          color: AppColors.secondary,
        ),
      ),
    ]..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.task_alt, color: AppColors.success),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nothing urgent coming up',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'No warranty expiry within 90 days or service due within 30 days.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final visibleItems = items.take(4).toList(growable: false);

    return Card(
      child: Column(
        children: [
          for (var index = 0; index < visibleItems.length; index++) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: visibleItems[index].color.withValues(
                  alpha: 0.12,
                ),
                foregroundColor: visibleItems[index].color,
                child: Icon(visibleItems[index].icon, size: 20),
              ),
              title: Text(
                visibleItems[index].title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(visibleItems[index].subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpenAppliance(visibleItems[index].applianceId),
            ),
            if (index != visibleItems.length - 1)
              const Divider(height: 1, indent: 72),
          ],
          if (items.length > visibleItems.length) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () =>
                          onOpenWarrantyCenter(WarrantyFilter.expiringSoon),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Warranties'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () =>
                          onOpenServiceCenter(ServiceFilter.dueSoon),
                      icon: const Icon(Icons.build_circle_outlined),
                      label: const Text('Service'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _relativeDayLabel(int days) {
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    return 'in $days days';
  }
}

class _UpcomingItem {
  const _UpcomingItem({
    required this.applianceId,
    required this.title,
    required this.subtitle,
    required this.daysRemaining,
    required this.icon,
    required this.color,
  });

  final String applianceId;
  final String title;
  final String subtitle;
  final int daysRemaining;
  final IconData icon;
  final Color color;
}
