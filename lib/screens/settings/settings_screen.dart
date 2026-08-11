import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../core/app_build_info.dart';
import '../../profile/profile_scope.dart';
import '../../security/app_lock_scope.dart';
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
