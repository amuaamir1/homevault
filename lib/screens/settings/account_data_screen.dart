import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../models/account_data_summary.dart';
import '../../models/cloud_sync_status.dart';
import '../../security/app_lock_scope.dart';
import '../../state/app_scope.dart';
import '../backup/backup_restore_screen.dart';
import 'account_deletion_screen.dart';
import 'device_storage_management_screen.dart';
import 'security_settings_screen.dart';

class AccountDataScreen extends StatelessWidget {
  const AccountDataScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out of HomeVault?'),
        content: const Text(
          'You will need to sign in again to access HomeVault on this device.',
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

    final lockController = AppLockScope.read(context);
    final authController = AuthScope.read(context);

    lockController.prepareForSignOut();
    await authController.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final store = AppScope.of(context);
    final summary = AccountDataSummary.fromAppliances(store.appliances);
    return Scaffold(
      appBar: AppBar(title: const Text('Account & data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(
            title: 'Account',
            subtitle: 'Your signed-in HomeVault account.',
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              key: const ValueKey('accountDataAccountSummary'),
              leading: const Icon(Icons.account_circle_outlined, size: 32),
              title: Text(
                auth.user?.email.isNotEmpty == true
                    ? auth.user!.email
                    : 'Signed-in HomeVault account',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                auth.isEmailVerified
                    ? 'Email verified'
                    : 'Email verification pending',
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            title: 'Your HomeVault data',
            subtitle:
                'A quick count of the records currently loaded for this account.',
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _DataCountTile(
                  icon: Icons.devices_other_outlined,
                  label: 'Appliances',
                  value: summary.applianceCount,
                ),
                const Divider(height: 1),
                _DataCountTile(
                  icon: Icons.description_outlined,
                  label: 'Documents & photos',
                  value: summary.documentCount,
                ),
                const Divider(height: 1),
                _DataCountTile(
                  icon: Icons.build_circle_outlined,
                  label: 'Service records',
                  value: summary.serviceRecordCount,
                ),
                const Divider(height: 1),
                _DataCountTile(
                  icon: Icons.support_agent_outlined,
                  label: 'Service requests',
                  value: summary.serviceRequestCount,
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('accountDataCloudSyncStatus'),
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('Cloud data status'),
                  subtitle: Text(_cloudSyncDescription(store.cloudSyncStatus)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            title: 'Data & security',
            subtitle: 'Manage backups, device storage, and HomeVault security.',
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('accountDataBackupTile'),
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Backup, restore & export'),
                  subtitle: const Text(
                    'Cloud and ZIP backups, recovery, plus CSV and PDF exports.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BackupRestoreScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('accountDataDeviceStorageTile'),
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('Device storage & cleanup'),
                  subtitle: const Text(
                    'Review local storage and safely release recoverable document copies.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DeviceStorageManagementScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('accountDataSecurityTile'),
                  leading: const Icon(Icons.security_outlined),
                  title: const Text('Security'),
                  subtitle: const Text(
                    'PIN, biometrics, and automatic locking.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SecuritySettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            title: 'Account access',
            subtitle:
                'Sign out of HomeVault or permanently delete this account.',
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('accountDataSignOutTile'),
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  subtitle: const Text(
                    'Sign in again using your HomeVault account.',
                  ),
                  onTap: () => _signOut(context),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('accountDataDeleteAccountTile'),
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Delete account',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Permanently remove your HomeVault account and stored data.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AccountDeletionScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Account deletion requires recent account verification and permanently '
            'removes this account and its stored HomeVault data.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static String _cloudSyncDescription(CloudSyncStatus status) {
    if (status.state == CloudSyncState.synced && status.hasPendingWrites) {
      return 'Changes are waiting to finish syncing.';
    }

    return switch (status.state) {
      CloudSyncState.synced => 'Your loaded HomeVault records are synced.',
      CloudSyncState.syncing => 'HomeVault is syncing your latest changes.',
      CloudSyncState.connecting => 'Connecting to HomeVault cloud sync.',
      CloudSyncState.offline =>
        'Offline. Changes stay available on this device and sync when connectivity returns.',
      CloudSyncState.error =>
        'Cloud sync needs attention. Your local HomeVault data remains available.',
      CloudSyncState.unavailable => 'Cloud sync is unavailable in this build.',
    };
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
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _DataCountTile extends StatelessWidget {
  const _DataCountTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(
        '$value',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}
