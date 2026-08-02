import 'package:flutter/material.dart';

import '../backup/backup_restore_screen.dart';
import '../service/service_center_screen.dart';
import '../warranty/warranty_screen.dart';
import 'security_settings_screen.dart';

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
                  const Text('Beta security build - version 1.8.0'),
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
                  title: Text('Local storage'),
                  subtitle: Text(
                    'Appliances, support details, warranties, service history, and documents are stored locally on this device.',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Backup, restore & export'),
                  subtitle: const Text(
                    'Create ZIP backups, restore data, and save CSV or PDF reports.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const BackupRestoreScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_outlined),
                  title: const Text('Security'),
                  subtitle: const Text(
                    'Change your PIN or lock HomeVault now.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const SecuritySettingsScreen(),
                      ),
                    );
                  },
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
                      MaterialPageRoute<void>(
                        builder: (context) => const WarrantyScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.home_repair_service_outlined),
                  title: const Text('Service center'),
                  subtitle: const Text(
                    'Manage maintenance history, costs, and next-service reminders.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const ServiceCenterScreen(),
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
                'HomeVault does not send your appliance data to a server. Exported backups and reports should be stored privately.',
              ),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'HomeVault',
                  applicationVersion: '1.8.0',
                  children: const [
                    Text(
                      'A personal appliance support, warranty, document, maintenance, backup, and reporting organizer under active development.',
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
