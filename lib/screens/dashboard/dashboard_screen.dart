import 'package:flutter/material.dart';

import '../../models/app_section.dart';
import '../../models/appliance.dart';
import '../../profile/profile_scope.dart';
import '../../services/homevault_report_service.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../widgets/hero_stat_card.dart';
import '../../widgets/quick_action_tile.dart';
import '../../widgets/warranty_status_chip.dart';
import '../service/service_center_screen.dart';
import '../warranty/warranty_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onNavigate,
    required this.onAddAppliance,
    required this.onOpenWarrantyCenter,
    required this.onOpenServiceCenter,
    required this.onOpenGlobalSearch,
    required this.onOpenReports,
    required this.onOpenAppliance,
  });

  final ValueChanged<AppSection> onNavigate;
  final Future<void> Function() onAddAppliance;
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
            tooltip: 'Search HomeVault',
            onPressed: onOpenGlobalSearch,
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Reports and insights',
            onPressed: onOpenReports,
            icon: const Icon(Icons.insights_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => store.initialize(force: true),
        child: SingleChildScrollView(
          key: const Key('dashboardScrollView'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstName.isEmpty ? 'Welcome' : 'Welcome $firstName',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage appliance details, warranties, invoices, support, and maintenance in one place.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondaryLight),
              ),
              if (store.loadWarning != null) ...[
                const SizedBox(height: 16),
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

              // ---- Hero stat: the one number that matters most ----
              HeroStatCard(
                title: 'ACTIVE WARRANTIES',
                value: '${report.warrantyCount(WarrantyStatus.active)}',
                subtitle:
                    '${report.totalAppliances} appliances tracked · '
                    '${report.warrantyCount(WarrantyStatus.expiringSoon)} expiring soon',
                icon: Icons.verified,
                onTap: () => onOpenWarrantyCenter(WarrantyFilter.active),
              ),
              const SizedBox(height: 16),

              // ---- Secondary stats: denser 3-column grid ----
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.95,
                children: [
                  MiniStatCard(
                    label: 'Appliances',
                    value: '${report.totalAppliances}',
                    icon: Icons.home_repair_service,
                    color: AppColors.primary,
                    onTap: () => onNavigate(AppSection.appliances),
                  ),
                  MiniStatCard(
                    label: 'Documents',
                    value: '${report.totalDocuments}',
                    icon: Icons.description_outlined,
                    color: AppColors.accent,
                    onTap: () => onNavigate(AppSection.documents),
                  ),
                  MiniStatCard(
                    label: 'Service records',
                    value: '${report.totalServiceRecords}',
                    icon: Icons.build_circle_outlined,
                    color: AppColors.secondary,
                    onTap: () => onOpenServiceCenter(ServiceFilter.all),
                  ),
                  MiniStatCard(
                    label: 'Service cost',
                    value: _formatAmount(report.totalServiceCost),
                    icon: Icons.payments_outlined,
                    color: AppColors.success,
                    onTap: onOpenReports,
                  ),
                  MiniStatCard(
                    label: 'Expiring soon',
                    value:
                        '${report.warrantyCount(WarrantyStatus.expiringSoon)}',
                    icon: Icons.warning_amber,
                    color: AppColors.warning,
                    onTap: () =>
                        onOpenWarrantyCenter(WarrantyFilter.expiringSoon),
                  ),
                  MiniStatCard(
                    label: 'Service due',
                    value: '${report.upcomingServices.length}',
                    icon: Icons.event_available_outlined,
                    color: AppColors.warning,
                    onTap: () => onOpenServiceCenter(ServiceFilter.dueSoon),
                  ),
                ],
              ),

              const SizedBox(height: 28),
              _AttentionSummary(
                missingWarrantyDates: report.appliancesWithoutWarrantyDate,
                missingDocuments: report.appliancesWithoutDocuments,
                missingSupport: report.appliancesWithoutSupport,
                activeServiceRecords: report.activeServiceRecords,
                onOpenReports: onOpenReports,
              ),
              const SizedBox(height: 30),
              Text(
                'Quick actions',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: [
                  QuickActionTile(
                    icon: Icons.add_circle_outline,
                    title: 'Add appliance',
                    color: AppColors.primary,
                    onTap: onAddAppliance,
                  ),
                  QuickActionTile(
                    icon: Icons.manage_search_outlined,
                    title: 'Global search',
                    color: AppColors.primary,
                    onTap: onOpenGlobalSearch,
                  ),
                  QuickActionTile(
                    icon: Icons.insights_outlined,
                    title: 'Reports',
                    color: AppColors.secondary,
                    onTap: onOpenReports,
                  ),
                  QuickActionTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'Documents',
                    color: AppColors.warning,
                    onTap: () => onNavigate(AppSection.documents),
                  ),
                  QuickActionTile(
                    icon: Icons.support_agent,
                    title: 'Support',
                    color: AppColors.success,
                    onTap: () => onNavigate(AppSection.support),
                  ),
                  QuickActionTile(
                    icon: Icons.home_repair_service_outlined,
                    title: 'Service center',
                    color: AppColors.secondary,
                    onTap: () => onOpenServiceCenter(ServiceFilter.all),
                  ),
                  QuickActionTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Warranty center',
                    color: AppColors.textSecondaryLight,
                    onTap: () => onOpenWarrantyCenter(WarrantyFilter.all),
                  ),
                ],
              ),
              const SizedBox(height: 30),
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
                      onPressed: () => onNavigate(AppSection.appliances),
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
                        leading: const CircleAvatar(
                          child: Icon(Icons.devices_other),
                        ),
                        title: Text(appliance.name),
                        subtitle: Text(
                          appliance.brand.isEmpty
                              ? appliance.category
                              : '${appliance.brand} • ${appliance.category}',
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
    );
  }

  String _formatAmount(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}

class _AttentionSummary extends StatelessWidget {
  const _AttentionSummary({
    required this.missingWarrantyDates,
    required this.missingDocuments,
    required this.missingSupport,
    required this.activeServiceRecords,
    required this.onOpenReports,
  });

  final int missingWarrantyDates;
  final int missingDocuments;
  final int missingSupport;
  final int activeServiceRecords;
  final Future<void> Function() onOpenReports;

  @override
  Widget build(BuildContext context) {
    final itemCount =
        missingWarrantyDates +
        missingDocuments +
        missingSupport +
        activeServiceRecords;
    final hasAttentionItems = itemCount > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenReports,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasAttentionItems
                    ? Icons.tips_and_updates_outlined
                    : Icons.task_alt_outlined,
                size: 32,
                color: hasAttentionItems
                    ? AppColors.warning
                    : AppColors.success,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasAttentionItems
                          ? 'Records need attention'
                          : 'Records look complete',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasAttentionItems
                          ? _summaryText()
                          : 'No obvious warranty, document, support, or service gaps were found.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Open reports',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _summaryText() {
    final items = <String>[
      if (missingWarrantyDates > 0)
        '$missingWarrantyDates missing warranty date',
      if (missingDocuments > 0) '$missingDocuments without documents',
      if (missingSupport > 0) '$missingSupport without support details',
      if (activeServiceRecords > 0)
        '$activeServiceRecords active service record${activeServiceRecords == 1 ? '' : 's'}',
    ];
    return items.join(' • ');
  }
}