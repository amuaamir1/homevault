import 'package:flutter/material.dart';

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
                  const Text('Sprint 3 development build'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.storage_outlined),
                  title: Text('Storage'),
                  subtitle: Text(
                    'Appliance records and document references are saved locally on this device.',
                  ),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.cloud_outlined),
                  title: Text('Cloud backup'),
                  subtitle: Text('Planned for a later phase.'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.notifications_outlined),
                  title: Text('Warranty reminders'),
                  subtitle: Text('Planned for Sprint 4.'),
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
                  applicationVersion: '1.3.0',
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
