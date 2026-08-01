import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/appliance.dart';
import '../../state/app_scope.dart';
import '../../widgets/empty_state.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appliances = AppScope.of(context)
        .appliances
        .where((appliance) => appliance.hasSupportDetails)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Customer support')),
      body: appliances.isEmpty
          ? const EmptyState(
              icon: Icons.support_agent,
              title: 'No support contacts yet',
              message:
                  'Add an appliance with its customer-care phone, email, or website. The details will appear here for quick access.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: appliances.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final appliance = appliances[index];
                return _SupportCard(
                  appliance: appliance,
                  onCopy: (label, value) => _copy(context, label, value),
                );
              },
            ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.appliance,
    required this.onCopy,
  });

  final Appliance appliance;
  final Future<void> Function(String label, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
              appliance.brand.isEmpty ? appliance.category : appliance.brand,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            if (appliance.supportPhone.isNotEmpty)
              _ContactRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: appliance.supportPhone,
                onCopy: onCopy,
              ),
            if (appliance.supportEmail.isNotEmpty)
              _ContactRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: appliance.supportEmail,
                onCopy: onCopy,
              ),
            if (appliance.supportWebsite.isNotEmpty)
              _ContactRow(
                icon: Icons.language,
                label: 'Website',
                value: appliance.supportWebsite,
                onCopy: onCopy,
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;
  final Future<void> Function(String label, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      trailing: IconButton(
        tooltip: 'Copy ${label.toLowerCase()}',
        onPressed: () {
          onCopy(label, value);
        },
        icon: const Icon(Icons.copy_outlined),
      ),
    );
  }
}
