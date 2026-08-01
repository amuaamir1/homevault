import 'package:flutter/material.dart';

import '../warranty/warranty_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HomeVault',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Sprint 4 development build'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.storage_outlined),
                  title: Text('Storage'),
                  subtitle: Text(
                    'Appliance records and document references are saved locally on this device.',
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.cloud_outlined),
                  title: Text('Cloud backup'),
                  subtitle: Text('Planned for a later phase.'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Warranty reminders'),
                  subtitle: const Text(
                    'Manage warranty status and local expiry notifications.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const WarrantyScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Privacy note'),
              subtitle: const Text(
                'HomeVault stores appliance information locally and does not send it to a server.',
              ),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'HomeVault',
                  applicationVersion: '1.4.0',
                  children: const [
                    Text(
                      'A personal appliance support and document organizer under active development.',
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
