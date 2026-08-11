import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../core/app_build_info.dart';
import '../../models/cloud_sync_status.dart';
import '../../profile/profile_scope.dart';
import '../../security/app_lock_scope.dart';
import '../../state/app_scope.dart';
import '../backup/backup_restore_screen.dart';
import '../feedback/beta_feedback_screen.dart';
import '../feedback/feedback_dashboard_screen.dart';
import '../../services/feedback_admin_service.dart';
import '../profile/profile_screen.dart';
import '../service/service_center_screen.dart';
import '../warranty/warranty_screen.dart';
import 'security_settings_screen.dart';
import 'account_deletion_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out of HomeVault?'),
        content: const Text(
          'HomeVault will require your email and password again. Your existing '
          'HomeVault PIN and biometric preference will remain saved for this account.',
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

  Future<void> _retryCloudSync(BuildContext context) async {
    final success = await AppScope.read(context).retryCloudSync();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Cloud sync connection refreshed.'
              : 'Cloud sync is still unavailable. Your local data remains safe.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context).profile;
    final store = AppScope.of(context);

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
                        Text(profile?.email ?? ''),
                        if (profile?.phoneNumber.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(profile!.phoneNumber),
                        ],
                        const SizedBox(height: 2),
                        const Text('Beta ${AppBuildInfo.versionAndRelease}'),
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
                        : '${profile.city}, ${profile.state} • ${profile.pinCode}',
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
                _CloudSyncTile(
                  status: store.cloudSyncStatus,
                  cloudSyncAvailable: store.cloudSyncAvailable,
                  onRetry: store.cloudSyncAvailable
                      ? () => _retryCloudSync(context)
                      : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Backup, restore & export'),
                  subtitle: const Text(
                    'Cloud and ZIP backups, recovery, plus CSV and PDF exports.',
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
                    'PIN, biometrics, and automatic locking.',
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
                  leading: const Icon(Icons.feedback_outlined),
                  title: const Text('Send beta feedback'),
                  subtitle: const Text(
                    'Report a bug or suggest an improvement.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const BetaFeedbackScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                _FeedbackDashboardAdminTile(
                  uid: AuthScope.of(context).user?.uid ?? '',
                ),
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
                  subtitle: const Text(
                    'Sign in again using your HomeVault account.',
                  ),
                  onTap: () => _signOut(context),
                ),
                const Divider(height: 1),
                ListTile(
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
        ],
      ),
    );
  }
}

class _CloudSyncTile extends StatelessWidget {
  const _CloudSyncTile({
    required this.status,
    required this.cloudSyncAvailable,
    required this.onRetry,
  });

  final CloudSyncStatus status;
  final bool cloudSyncAvailable;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final details = _statusDetails(status, cloudSyncAvailable);

    return ListTile(
      key: const Key('cloudSyncStatusTile'),
      isThreeLine: true,
      leading: Icon(details.icon),
      title: Row(
        children: [
          const Expanded(child: Text('Cloud sync')),
          _SyncStateBadge(label: details.badgeLabel),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${details.statusText}\n'
          'Appliances and documents sync automatically across your signed-in devices.',
        ),
      ),
      trailing: cloudSyncAvailable
          ? IconButton(
              key: const Key('cloudSyncRetryButton'),
              tooltip: 'Retry cloud sync',
              onPressed:
                  status.state == CloudSyncState.connecting ||
                      status.state == CloudSyncState.syncing
                  ? null
                  : onRetry,
              icon: const Icon(Icons.refresh),
            )
          : null,
    );
  }

  _SyncStatusDetails _statusDetails(
    CloudSyncStatus status,
    bool cloudSyncAvailable,
  ) {
    if (!cloudSyncAvailable) {
      return const _SyncStatusDetails(
        icon: Icons.phone_android_outlined,
        badgeLabel: 'Local',
        statusText: 'This build is using local appliance storage.',
      );
    }

    return switch (status.state) {
      CloudSyncState.connecting => const _SyncStatusDetails(
        icon: Icons.cloud_sync_outlined,
        badgeLabel: 'Connecting',
        statusText: 'Connecting to the HomeVault cloud...',
      ),
      CloudSyncState.syncing => _SyncStatusDetails(
        icon: Icons.cloud_upload_outlined,
        badgeLabel: 'Syncing',
        statusText: status.hasPendingWrites
            ? 'Syncing changes to your other devices...'
            : 'Checking cloud data...',
      ),
      CloudSyncState.synced => _SyncStatusDetails(
        icon: Icons.cloud_done_outlined,
        badgeLabel: 'Synced',
        statusText: _lastSyncText(status.lastSyncedAt),
      ),
      CloudSyncState.offline => _SyncStatusDetails(
        icon: Icons.cloud_off_outlined,
        badgeLabel: 'Offline',
        statusText: status.hasPendingWrites
            ? 'Offline. Changes are saved locally and will sync automatically.'
            : 'Offline. Showing the last data saved on this device.',
      ),
      CloudSyncState.error => _SyncStatusDetails(
        icon: Icons.sync_problem_outlined,
        badgeLabel: 'Problem',
        statusText:
            status.message ??
            'Cloud sync has a problem. Tap refresh to try again.',
      ),
      CloudSyncState.unavailable => const _SyncStatusDetails(
        icon: Icons.cloud_outlined,
        badgeLabel: 'Unavailable',
        statusText: 'Cloud sync is not available for this session.',
      ),
    };
  }

  String _lastSyncText(DateTime? value) {
    if (value == null) {
      return 'Cloud data is synchronized.';
    }

    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return 'Synced. Last confirmed $day/$month/${local.year} at $hour:$minute.';
  }
}

class _SyncStateBadge extends StatelessWidget {
  const _SyncStateBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SyncStatusDetails {
  const _SyncStatusDetails({
    required this.icon,
    required this.badgeLabel,
    required this.statusText,
  });

  final IconData icon;
  final String badgeLabel;
  final String statusText;
}

class _FeedbackDashboardAdminTile extends StatefulWidget {
  const _FeedbackDashboardAdminTile({required this.uid});

  final String uid;

  @override
  State<_FeedbackDashboardAdminTile> createState() =>
      _FeedbackDashboardAdminTileState();
}

class _FeedbackDashboardAdminTileState
    extends State<_FeedbackDashboardAdminTile> {
  late Future<bool> _adminCheck;

  @override
  void initState() {
    super.initState();
    _adminCheck = _check();
  }

  @override
  void didUpdateWidget(covariant _FeedbackDashboardAdminTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) _adminCheck = _check();
  }

  Future<bool> _check() async {
    if (widget.uid.trim().isEmpty) {
      return false;
    }

    try {
      return await FirebaseFeedbackAdminRepository().isAdmin(widget.uid);
    } catch (_) {
      // The admin dashboard is an optional Settings feature. Widget tests and
      // other non-Firebase app shells may build Settings without initializing
      // the default Firebase app. In that case, simply hide the admin tile
      // instead of allowing the optional admin check to break unrelated UI.
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.trim().isEmpty) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      future: _adminCheck,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('Feedback dashboard'),
              subtitle: const Text(
                'Review, prioritise, and resolve feedback from all users.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        FeedbackDashboardScreen(adminUid: widget.uid),
                  ),
                );
              },
            ),
            const Divider(height: 1),
          ],
        );
      },
    );
  }
}
