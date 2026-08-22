import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/appliance.dart';
import '../../models/homevault_reminder.dart';
import '../../services/homevault_error_presenter.dart';
import '../../services/reminder_center_service.dart';
import '../../services/reminder_notification_gateway.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../appliances/appliance_details_screen.dart';

enum ReminderCenterFilter {
  all,
  attention,
  warranty,
  amc,
  maintenance,
  notificationsOff,
}

extension ReminderCenterFilterDetails on ReminderCenterFilter {
  String get label => switch (this) {
    ReminderCenterFilter.all => 'All',
    ReminderCenterFilter.attention => 'Attention',
    ReminderCenterFilter.warranty => 'Warranty',
    ReminderCenterFilter.amc => 'AMC',
    ReminderCenterFilter.maintenance => 'Maintenance',
    ReminderCenterFilter.notificationsOff => 'Notifications off',
  };
}

class ReminderCenterScreen extends StatefulWidget {
  const ReminderCenterScreen({
    super.key,
    this.now,
    this.notificationGateway,
    this.onOpenAppliance,
  });

  final DateTime? now;
  final ReminderNotificationGateway? notificationGateway;
  final Future<void> Function(String applianceId)? onOpenAppliance;

  @override
  State<ReminderCenterScreen> createState() => _ReminderCenterScreenState();
}

class _ReminderCenterScreenState extends State<ReminderCenterScreen> {
  static const _service = ReminderCenterService();

  late final ReminderNotificationGateway _notifications;
  ReminderCenterFilter _filter = ReminderCenterFilter.all;
  bool? _notificationsEnabled;
  int? _pendingCount;
  bool _notificationStatusLoading = true;
  bool _notificationActionBusy = false;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _notifications =
        widget.notificationGateway ?? LocalReminderNotificationGateway();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadNotificationStatus());
    });
  }

  Future<void> _loadNotificationStatus() async {
    if (!mounted) return;
    setState(() => _notificationStatusLoading = true);

    try {
      final enabled = await _notifications.notificationsEnabled();
      final pending = await _notifications.pendingReminderCount();
      if (!mounted) return;
      setState(() {
        if (enabled != null) _notificationsEnabled = enabled;
        _pendingCount = pending;
        _notificationStatusLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _notificationStatusLoading = false);
    }
  }

  Future<void> _enableNotifications() async {
    if (_notificationActionBusy) return;
    setState(() => _notificationActionBusy = true);

    try {
      final granted = await _notifications.requestPermission();
      if (!mounted) return;
      _notificationsEnabled = granted;

      if (granted) {
        await AppScope.read(context).rescheduleWarrantyReminders();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              granted
                  ? 'Reminder notifications are enabled.'
                  : 'Notifications are still off. You can enable them in your device settings.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'Notification permission could not be updated.',
        operation: 'Enabling reminder notifications',
        telemetryContext: const {'screen': 'reminder_center'},
      );
    } finally {
      if (mounted) setState(() => _notificationActionBusy = false);
    }

    await _loadNotificationStatus();
  }

  Future<void> _refreshReminderSchedule() async {
    if (_notificationActionBusy) return;
    setState(() => _notificationActionBusy = true);

    try {
      await AppScope.read(context).rescheduleWarrantyReminders();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Reminder schedule refreshed.')),
        );
    } catch (error) {
      if (!mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The reminder schedule could not be refreshed.',
        operation: 'Refreshing reminder schedule',
        telemetryContext: const {'screen': 'reminder_center'},
      );
    } finally {
      if (mounted) setState(() => _notificationActionBusy = false);
    }

    await _loadNotificationStatus();
  }

  Future<void> _sendTestNotification(List<Appliance> appliances) async {
    if (_notificationActionBusy) return;
    setState(() => _notificationActionBusy = true);

    try {
      await _notifications.showTestNotification(
        appliance: appliances.isEmpty ? null : appliances.first,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Test notification sent.')),
        );
    } catch (error) {
      if (!mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The test notification could not be sent.',
        operation: 'Sending reminder test notification',
        telemetryContext: const {'screen': 'reminder_center'},
      );
    } finally {
      if (mounted) setState(() => _notificationActionBusy = false);
    }
  }

  Future<void> _openAppliance(String applianceId) async {
    final callback = widget.onOpenAppliance;
    if (callback != null) {
      await callback(applianceId);
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ApplianceDetailsScreen(applianceId: applianceId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final reminders = _service.build(store.appliances, now: _now);
    final summary = _service.summarize(reminders, now: _now);
    final visible = reminders
        .where((reminder) => _matchesFilter(reminder, _now))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Reminder center')),
      body: RefreshIndicator(
        onRefresh: () async {
          await store.refresh();
          await store.rescheduleWarrantyReminders();
          await _loadNotificationStatus();
        },
        child: ListView(
          key: const ValueKey('reminderCenterList'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _NotificationStatusCard(
              enabled: _notificationsEnabled,
              pendingCount: _pendingCount,
              loading: _notificationStatusLoading,
              busy: _notificationActionBusy,
              hasAppliances: store.appliances.isNotEmpty,
              onEnable: _enableNotifications,
              onRefreshSchedule: _refreshReminderSchedule,
              onTest: () => _sendTestNotification(store.appliances),
            ),
            const SizedBox(height: 14),
            _ReminderSummary(summary: summary),
            const SizedBox(height: 14),
            _ReminderFilters(
              selected: _filter,
              onSelected: (filter) => setState(() => _filter = filter),
            ),
            const SizedBox(height: 14),
            if (visible.isEmpty)
              EmptyState(
                icon: reminders.isEmpty
                    ? Icons.notifications_none_outlined
                    : Icons.filter_alt_off_outlined,
                title: reminders.isEmpty
                    ? 'No reminders yet'
                    : 'No reminders in this filter',
                message: reminders.isEmpty
                    ? 'Add a warranty or AMC expiry date, or a next service date, to see it here.'
                    : 'Choose another filter to see your warranty, AMC, and maintenance dates.',
              )
            else
              ...visible.map(
                (reminder) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReminderCard(
                    reminder: reminder,
                    now: _now,
                    onTap: () => _openAppliance(reminder.applianceId),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _matchesFilter(HomeVaultReminder reminder, DateTime now) {
    return switch (_filter) {
      ReminderCenterFilter.all => true,
      ReminderCenterFilter.attention => reminder.needsAttentionAt(now),
      ReminderCenterFilter.warranty =>
        reminder.type == HomeVaultReminderType.warranty,
      ReminderCenterFilter.amc => reminder.type == HomeVaultReminderType.amc,
      ReminderCenterFilter.maintenance =>
        reminder.type == HomeVaultReminderType.maintenance,
      ReminderCenterFilter.notificationsOff => !reminder.notificationEnabled,
    };
  }
}

class _NotificationStatusCard extends StatelessWidget {
  const _NotificationStatusCard({
    required this.enabled,
    required this.pendingCount,
    required this.loading,
    required this.busy,
    required this.hasAppliances,
    required this.onEnable,
    required this.onRefreshSchedule,
    required this.onTest,
  });

  final bool? enabled;
  final int? pendingCount;
  final bool loading;
  final bool busy;
  final bool hasAppliances;
  final VoidCallback onEnable;
  final VoidCallback onRefreshSchedule;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = enabled == true;
    final statusColor = isEnabled ? AppColors.success : AppColors.warning;

    final title = loading
        ? 'Checking notification status...'
        : isEnabled
        ? 'Notifications enabled'
        : enabled == false
        ? 'Notifications are off'
        : 'Reminder notifications';

    final subtitle = loading
        ? 'HomeVault is checking this device.'
        : isEnabled
        ? '${_pendingLabel(pendingCount ?? 0)} HomeVault keeps the schedule in sync when your appliance data changes.'
        : enabled == false
        ? 'Enable notifications to receive warranty, AMC, and maintenance alerts. Your reminder dates remain available here.'
        : 'HomeVault can schedule local warranty, AMC, and maintenance alerts on supported devices.';

    return Card(
      key: const ValueKey('reminderNotificationStatusCard'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isEnabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isEnabled)
                  FilledButton.tonalIcon(
                    key: const ValueKey('enableReminderNotificationsButton'),
                    onPressed: busy ? null : onEnable,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Enable notifications'),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey('refreshReminderScheduleButton'),
                  onPressed: busy || !hasAppliances ? null : onRefreshSchedule,
                  icon: const Icon(Icons.sync),
                  label: const Text('Refresh schedule'),
                ),
                if (isEnabled)
                  TextButton.icon(
                    key: const ValueKey('testReminderNotificationButton'),
                    onPressed: busy ? null : onTest,
                    icon: const Icon(Icons.notifications_none_outlined),
                    label: const Text('Send test'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _pendingLabel(int count) {
    if (count == 0) return 'No local reminders are currently scheduled.';
    if (count == 1) return '1 local reminder is currently scheduled.';
    return '$count local reminders are currently scheduled.';
  }
}

class _ReminderSummary extends StatelessWidget {
  const _ReminderSummary({required this.summary});

  final ReminderCenterSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Attention', summary.attention, AppColors.warning),
      ('Overdue', summary.overdue, AppColors.danger),
      ('Next 30 days', summary.next30Days, AppColors.secondary),
      ('Notifications on', summary.notificationsOn, AppColors.success),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            _SummaryPill(
              label: items[index].$1,
              value: items[index].$2,
              color: items[index].$3,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ReminderFilters extends StatelessWidget {
  const _ReminderFilters({required this.selected, required this.onSelected});

  final ReminderCenterFilter selected;
  final ValueChanged<ReminderCenterFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (
            var index = 0;
            index < ReminderCenterFilter.values.length;
            index++
          ) ...[
            if (index > 0) const SizedBox(width: 8),
            FilterChip(
              key: ValueKey(
                'reminderFilter_${ReminderCenterFilter.values[index].name}',
              ),
              label: Text(ReminderCenterFilter.values[index].label),
              selected: selected == ReminderCenterFilter.values[index],
              onSelected: (_) => onSelected(ReminderCenterFilter.values[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.now,
    required this.onTap,
  });

  final HomeVaultReminder reminder;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timing = reminder.timingAt(now);
    final typeColor = _typeColor(reminder.type);
    final statusColor = _timingColor(timing);
    final provider = reminder.provider.trim();

    return Card(
      key: ValueKey('reminderCard_${reminder.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(_typeIcon(reminder.type), color: typeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            reminder.applianceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(
                          label: _timingLabel(reminder, now),
                          color: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${reminder.type.label} • ${_date(reminder.dueDate)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (provider.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        provider,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          reminder.notificationEnabled
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_off_outlined,
                          size: 17,
                          color: reminder.notificationEnabled
                              ? AppColors.success
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _notificationLabel(reminder, now),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _typeIcon(HomeVaultReminderType type) => switch (type) {
    HomeVaultReminderType.warranty => Icons.verified_user_outlined,
    HomeVaultReminderType.amc => Icons.assignment_outlined,
    HomeVaultReminderType.maintenance => Icons.build_circle_outlined,
  };

  static Color _typeColor(HomeVaultReminderType type) => switch (type) {
    HomeVaultReminderType.warranty => AppColors.primary,
    HomeVaultReminderType.amc => AppColors.warning,
    HomeVaultReminderType.maintenance => AppColors.secondary,
  };

  static Color _timingColor(HomeVaultReminderTiming timing) => switch (timing) {
    HomeVaultReminderTiming.overdue => AppColors.danger,
    HomeVaultReminderTiming.today => AppColors.warning,
    HomeVaultReminderTiming.dueSoon => AppColors.warning,
    HomeVaultReminderTiming.upcoming => AppColors.primary,
  };

  static String _timingLabel(HomeVaultReminder reminder, DateTime now) {
    final days = reminder.daysUntilDueAt(now);
    if (days < -1) return '${-days} days overdue';
    if (days == -1) return '1 day overdue';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  static String _notificationLabel(HomeVaultReminder reminder, DateTime now) {
    if (!reminder.notificationEnabled) return 'Notification off';
    if (reminder.daysUntilDueAt(now) < 0) return 'Reminder was enabled';
    if (reminder.reminderWindowHasStartedAt(now)) {
      return 'Reminder window has started';
    }
    final days = reminder.reminderDaysBefore;
    return days == 0
        ? 'Notify on the due date'
        : 'Notify $days ${days == 1 ? 'day' : 'days'} before';
  }

  static String _date(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
