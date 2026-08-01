import 'package:flutter/material.dart';

import '../../models/appliance.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/quick_action_tile.dart';
import '../../widgets/warranty_status_chip.dart';
import '../main_navigation.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onNavigate,
    required this.onAddAppliance,
  });

  final ValueChanged<AppSection> onNavigate;
  final Future<void> Function() onAddAppliance;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final recentAppliances = store.recentAppliances;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HomeVault',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => store.initialize(force: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '👋 ${_greeting()}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage appliance details, warranties, invoices, and support contacts in one place.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  DashboardCard(
                    icon: Icons.home_repair_service,
                    title: 'Appliances',
                    value: '${store.totalCount}',
                    color: AppColors.primary,
                    onTap: () => onNavigate(AppSection.appliances),
                  ),
                  DashboardCard(
                    icon: Icons.verified,
                    title: 'Active warranty',
                    value: '${store.warrantyCount(WarrantyStatus.active)}',
                    color: AppColors.success,
                    onTap: () => onNavigate(AppSection.appliances),
                  ),
                  DashboardCard(
                    icon: Icons.warning_amber,
                    title: 'Expiring soon',
                    value:
                        '${store.warrantyCount(WarrantyStatus.expiringSoon)}',
                    color: AppColors.warning,
                    onTap: () => onNavigate(AppSection.appliances),
                  ),
                  DashboardCard(
                    icon: Icons.cancel,
                    title: 'Expired',
                    value: '${store.warrantyCount(WarrantyStatus.expired)}',
                    color: AppColors.danger,
                    onTap: () => onNavigate(AppSection.appliances),
                  ),
                ],
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
                    onTap: () {
                      onAddAppliance();
                    },
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
                    icon: Icons.settings,
                    title: 'Settings',
                    color: AppColors.textSecondary,
                    onTap: () => onNavigate(AppSection.settings),
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
                          onPressed: () {
                            onAddAppliance();
                          },
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
                        onTap: () => onNavigate(AppSection.appliances),
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
}
