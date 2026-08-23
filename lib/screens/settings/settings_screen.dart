import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../core/app_build_info.dart';
import '../../profile/profile_scope.dart';
import '../../services/feedback_admin_service.dart';
import '../feedback/beta_feedback_screen.dart';
import '../feedback/feedback_dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../reminders/reminder_center_screen.dart';
import '../service/service_center_screen.dart';
import 'account_data_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context).profile;
    final auth = AuthScope.of(context);

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
                        Text(profile?.email ?? auth.user?.email ?? ''),
                        const SizedBox(height: 6),
                        Container(
                          key: const ValueKey(
                            'settingsEmailVerificationStatus',
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: auth.isEmailVerified
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                auth.isEmailVerified
                                    ? Icons.verified_outlined
                                    : Icons.mark_email_unread_outlined,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                auth.isEmailVerified
                                    ? 'Email verified'
                                    : 'Email verification pending',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        if (profile?.phoneNumber.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
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
                  key: const ValueKey('settingsAccountDataTile'),
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: const Text('Account & data'),
                  subtitle: const Text(
                    'Manage your data, backups, security, and account access.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const AccountDataScreen(),
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
                  key: const ValueKey('settingsReminderCenterTile'),
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Reminder center'),
                  subtitle: const Text(
                    'Warranty, AMC, and maintenance alerts in one place.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const ReminderCenterScreen(),
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
