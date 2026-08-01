import 'package:flutter/material.dart';

import '../../models/appliance.dart';
import '../../state/app_scope.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/warranty_status_chip.dart';
import 'appliance_details_screen.dart';

class AppliancesScreen extends StatefulWidget {
  const AppliancesScreen({
    super.key,
    required this.onAddAppliance,
  });

  final Future<void> Function() onAddAppliance;

  @override
  State<AppliancesScreen> createState() => _AppliancesScreenState();
}

class _AppliancesScreenState extends State<AppliancesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final query = _query.trim().toLowerCase();
    final appliances = store.appliances.where((appliance) {
      if (query.isEmpty) {
        return true;
      }
      return appliance.name.toLowerCase().contains(query) ||
          appliance.brand.toLowerCase().contains(query) ||
          appliance.category.toLowerCase().contains(query) ||
          appliance.modelNumber.toLowerCase().contains(query);
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Appliances')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onAddAppliance,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SearchBar(
                hintText: 'Search appliances',
                leading: const Icon(Icons.search),
                trailing: [
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      onPressed: () => setState(() => _query = ''),
                      icon: const Icon(Icons.close),
                    ),
                ],
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: appliances.isEmpty
                  ? EmptyState(
                      icon: query.isEmpty
                          ? Icons.home_repair_service_outlined
                          : Icons.search_off,
                      title: query.isEmpty
                          ? 'No appliances yet'
                          : 'No matching appliances',
                      message: query.isEmpty
                          ? 'Add an appliance to keep its warranty, invoice reference, and support details together.'
                          : 'Try another name, brand, model, or category.',
                      actionLabel: query.isEmpty ? 'Add appliance' : null,
                      onAction: query.isEmpty ? widget.onAddAppliance : null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: appliances.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final appliance = appliances[index];
                        return _ApplianceCard(appliance: appliance);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplianceCard extends StatelessWidget {
  const _ApplianceCard({required this.appliance});

  final Appliance appliance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ApplianceDetailsScreen(appliance: appliance),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                child: Icon(_categoryIcon(appliance.category)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appliance.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [appliance.brand, appliance.modelNumber]
                          .where((value) => value.trim().isNotEmpty)
                          .join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    WarrantyStatusChip(
                      status: appliance.warrantyStatusAt(DateTime.now()),
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

  IconData _categoryIcon(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('air')) return Icons.ac_unit;
    if (normalized.contains('kitchen')) return Icons.kitchen_outlined;
    if (normalized.contains('laundry')) return Icons.local_laundry_service_outlined;
    if (normalized.contains('television')) return Icons.tv;
    if (normalized.contains('computer')) return Icons.computer;
    if (normalized.contains('mobile')) return Icons.smartphone;
    return Icons.devices_other;
  }
}
