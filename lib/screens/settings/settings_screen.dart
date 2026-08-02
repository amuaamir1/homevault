import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../profile/profile_scope.dart';
import '../../security/app_lock_scope.dart';
import '../backup/backup_restore_screen.dart';
import '../profile/profile_screen.dart';
import '../service/service_center_screen.dart';
import '../warranty/warranty_screen.dart';
import 'security_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out of HomeVault?'),
        content: const Text(
          'Your appliance records and documents will remain stored locally on this device. Sign in with the same mobile number to continue using this local vault.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await AppLockScope.read(context).resetPinForOtpRecovery();
    if (!context.mounted) return;
    await AuthScope.read(context).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context).profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Text(
                      profile?.firstName.isNotEmpty == true
                          ? profile!.firstName.substring(0, 1).toUpperCase()
                          : 'H',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.fullName ?? 'HomeVault user',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(profile?.phoneNumber ?? ''),
                        const SizedBox(height: 2),
                        const Text('India beta build â€¢ version 1.9.0'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('My profile'),
                  subtitle: Text(
                    profile == null
                        ? 'Add your name and service address.'
                        : '${profile.city}, ${profile.state} â€¢ ${profile.pinCode}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.storage_outlined),
                  title: Text('Local appliance storage'),
                  subtitle: Text(
                    'Appliances, warranties, service history, and document files remain on this device.',
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
                    'Create, change, or remove the local app PIN.',
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
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  subtitle: const Text('Sign in again using mobile OTP.'),
                  onTap: () => _signOut(context),
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
                'Your account and profile are stored in Firebase. Appliance records and attached files remain local unless you export or restore a backup.',
              ),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'HomeVault',
                  applicationVersion: '1.9.0',
                  children: const [
                    Text(
                      'A personal appliance support, warranty, document, maintenance, backup, and reporting organizer for homes in India.',
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
