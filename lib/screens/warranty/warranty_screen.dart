import 'package:flutter/material.dart';

import '../../models/appliance.dart';
import '../../services/warranty_notification_service.dart';
import '../../state/app_scope.dart';
import '../../state/appliance_store.dart';
import '../../theme/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/warranty_status_chip.dart';
import '../appliances/appliance_details_screen.dart';

enum WarrantyFilter { all, active, expiringSoon, expired, notProvided }

enum WarrantySort { expirySoonest, name, recentlyAdded }

class WarrantyScreen extends StatefulWidget {
  const WarrantyScreen({super.key, this.initialFilter = WarrantyFilter.all});

  final WarrantyFilter initialFilter;

  @override
  State<WarrantyScreen> createState() => _WarrantyScreenState();
}

class _WarrantyScreenState extends State<WarrantyScreen> {
  late WarrantyFilter _filter;
  WarrantySort _sort = WarrantySort.expirySoonest;
  String _query = '';
  bool? _notificationsEnabled;
  int _pendingReminderCount = 0;
  bool _checkingNotifications = true;
  bool _requestingPermission = false;
  bool _sendingTestNotification = false;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _loadNotificationStatus();
  }

  Future<void> _loadNotificationStatus() async {
    try {
      final service = WarrantyNotificationService.instance;
      final enabled = await service.notificationsEnabled();
      final pending = await service.pendingReminderCount();
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = enabled;
        _pendingReminderCount = pending;
        _checkingNotifications = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkingNotifications = false);
    }
  }

  Future<void> _enableNotifications() async {
    setState(() => _requestingPermission = true);
    try {
      final granted = await WarrantyNotificationService.instance
          .requestPermission();
      if (granted && mounted) {
        await AppScope.read(context).rescheduleWarrantyReminders();
      }
      await _loadNotificationStatus();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'HomeVault notifications are enabled.'
                : 'Notification permission was not granted.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification permission could not be updated.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _requestingPermission = false);
      }
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() => _sendingTestNotification = true);
    try {
      final store = AppScope.read(context);
      final appliance = store.appliances.isEmpty
          ? null
          : store.appliances.first;
      await WarrantyNotificationService.instance.showTestNotification(
        appliance: appliance,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Test notification sent.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The test notification could not be sent.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingTestNotification = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final now = DateTime.now();
    final normalizedQuery = _query.trim().toLowerCase();
    final appliances =
        store.appliances
            .where((appliance) {
              if (!_matchesFilter(appliance, now)) {
                return false;
              }
              if (normalizedQuery.isEmpty) {
                return true;
              }

              return appliance.name.toLowerCase().contains(normalizedQuery) ||
                  appliance.brand.toLowerCase().contains(normalizedQuery) ||
                  appliance.warrantyProvider.toLowerCase().contains(
                    normalizedQuery,
                  ) ||
                  appliance.warrantyReference.toLowerCase().contains(
                    normalizedQuery,
                  ) ||
                  appliance.extendedWarrantyProvider.toLowerCase().contains(
                    normalizedQuery,
                  ) ||
                  appliance.warrantyClaimNumber.toLowerCase().contains(
                    normalizedQuery,
                  );
            })
            .toList(growable: false)
          ..sort(_compareAppliances);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warranty center'),
        actions: [
          PopupMenuButton<WarrantySort>(
            tooltip: 'Sort warranties',
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: WarrantySort.expirySoonest,
                child: Text('Expiry soonest'),
              ),
              PopupMenuItem(
                value: WarrantySort.name,
                child: Text('Appliance name'),
              ),
              PopupMenuItem(
                value: WarrantySort.recentlyAdded,
                child: Text('Recently added'),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await store.initialize(force: true);
            await _loadNotificationStatus();
          },
          child: ListView(
            key: const Key('warrantyCenterList'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _NotificationCard(
                isChecking: _checkingNotifications,
                isEnabled: _notificationsEnabled,
                pendingCount: _pendingReminderCount,
                isRequesting: _requestingPermission,
                isSendingTest: _sendingTestNotification,
                onEnable: _enableNotifications,
                onSendTest: _sendTestNotification,
              ),
              const SizedBox(height: 16),
              _WarrantySummary(store: store, now: now),
              const SizedBox(height: 18),
              SearchBar(
                hintText: 'Search appliance, brand, provider, or claim',
                leading: const Icon(Icons.search),
                trailing: [
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      onPressed: () => setState(() => _query = ''),
                      icon: const Icon(Icons.close),
                    ),
                ],
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: WarrantyFilter.values
                      .map(
                        (filter) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(_filterLabel(filter)),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              if (appliances.isEmpty)
                EmptyState(
                  icon: normalizedQuery.isEmpty
                      ? Icons.verified_user_outlined
                      : Icons.search_off,
                  title: normalizedQuery.isEmpty
                      ? 'No warranties in this category'
                      : 'No matching warranties',
                  message: normalizedQuery.isEmpty
                      ? 'Update an appliance with a warranty date or choose another filter.'
                      : 'Try another appliance, brand, provider, reference, or claim number.',
                )
              else
                ...appliances.map(
                  (appliance) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WarrantyCard(appliance: appliance, now: now),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesFilter(Appliance appliance, DateTime now) {
    final status = appliance.warrantyStatusAt(now);
    return switch (_filter) {
      WarrantyFilter.all => true,
      WarrantyFilter.active => status == WarrantyStatus.active,
      WarrantyFilter.expiringSoon => status == WarrantyStatus.expiringSoon,
      WarrantyFilter.expired => status == WarrantyStatus.expired,
      WarrantyFilter.notProvided => status == WarrantyStatus.notProvided,
    };
  }

  int _compareAppliances(Appliance a, Appliance b) {
    return switch (_sort) {
      WarrantySort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      WarrantySort.recentlyAdded => b.createdAt.compareTo(a.createdAt),
      WarrantySort.expirySoonest => _compareExpiryDates(a, b),
    };
  }

  int _compareExpiryDates(Appliance a, Appliance b) {
    final aExpiry = a.effectiveWarrantyExpiryDate;
    final bExpiry = b.effectiveWarrantyExpiryDate;
    if (aExpiry == null && bExpiry == null) {
      return a.name.compareTo(b.name);
    }
    if (aExpiry == null) return 1;
    if (bExpiry == null) return -1;
    return aExpiry.compareTo(bExpiry);
  }

  String _filterLabel(WarrantyFilter filter) => switch (filter) {
    WarrantyFilter.all => 'All',
    WarrantyFilter.active => 'Active',
    WarrantyFilter.expiringSoon => 'Expiring soon',
    WarrantyFilter.expired => 'Expired',
    WarrantyFilter.notProvided => 'No date',
  };
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.isChecking,
    required this.isEnabled,
    required this.pendingCount,
    required this.isRequesting,
    required this.isSendingTest,
    required this.onEnable,
    required this.onSendTest,
  });

  final bool isChecking;
  final bool? isEnabled;
  final int pendingCount;
  final bool isRequesting;
  final bool isSendingTest;
  final Future<void> Function() onEnable;
  final Future<void> Function() onSendTest;

  @override
  Widget build(BuildContext context) {
    final enabled = isEnabled == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              child: Icon(
                enabled
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Warranty and maintenance reminders',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isChecking
                        ? 'Checking notification permission...'
                        : enabled
                        ? '$pendingCount reminder${pendingCount == 1 ? '' : 's'} currently scheduled across warranties and maintenance.'
                        : 'Enable notifications to receive warranty expiry alerts.',
                  ),
                  if (!isChecking) ...[
                    const SizedBox(height: 10),
                    if (!enabled)
                      FilledButton.tonalIcon(
                        onPressed: isRequesting ? null : onEnable,
                        icon: isRequesting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.notifications_outlined),
                        label: const Text('Enable notifications'),
                      )
                    else
                      FilledButton.tonalIcon(
                        onPressed: isSendingTest ? null : onSendTest,
                        icon: isSendingTest
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: const Text('Send test notification'),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarrantySummary extends StatelessWidget {
  const _WarrantySummary({required this.store, required this.now});

  final ApplianceStore store;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Active',
        store.warrantyCount(WarrantyStatus.active, now: now),
        AppColors.success,
      ),
      (
        'Expiring',
        store.warrantyCount(WarrantyStatus.expiringSoon, now: now),
        AppColors.warning,
      ),
      (
        'Expired',
        store.warrantyCount(WarrantyStatus.expired, now: now),
        AppColors.danger,
      ),
      (
        'No date',
        store.warrantyCount(WarrantyStatus.notProvided, now: now),
        AppColors.textSecondaryLight,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: item.$3.withValues(alpha: 0.12),
                  child: Text(
                    '${item.$2}',
                    style: TextStyle(
                      color: item.$3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WarrantyCard extends StatelessWidget {
  const _WarrantyCard({required this.appliance, required this.now});

  final Appliance appliance;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final expiryDate = appliance.effectiveWarrantyExpiryDate;
    final daysRemaining = appliance.warrantyDaysRemainingAt(now);
    final status = appliance.warrantyStatusAt(now);
    final providerText = [
      appliance.brand,
      appliance.warrantyProvider,
    ].where((value) => value.trim().isNotEmpty).join(' • ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  ApplianceDetailsScreen(applianceId: appliance.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      appliance.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  WarrantyStatusChip(status: status),
                ],
              ),
              if (providerText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  providerText,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.event_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      expiryDate == null
                          ? 'Warranty expiry not provided'
                          : 'Expires ${_formatDate(expiryDate)} • ${_remainingText(daysRemaining)}',
                    ),
                  ),
                ],
              ),
              if (appliance.warrantyMarkedExpired) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.gpp_bad_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Manually marked out of warranty'),
                  ],
                ),
              ],
              if (appliance.hasExtendedWarranty) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.verified_user_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Extended warranty included'),
                  ],
                ),
              ],
              if (appliance.warrantyReminderEnabled) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reminder ${appliance.warrantyReminderDaysBefore} days before expiry',
                      ),
                    ),
                  ],
                ),
              ],
              if (appliance.warrantyClaimStatus != WarrantyClaimStatus.none ||
                  appliance.warrantyClaimNumber.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.assignment_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Claim: ${appliance.warrantyClaimStatus.label}'
                        '${appliance.warrantyClaimNumber.trim().isEmpty ? '' : ' • ${appliance.warrantyClaimNumber}'}',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            ApplianceDetailsScreen(applianceId: appliance.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('View details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _remainingText(int? daysRemaining) {
  if (daysRemaining == null) return 'No date';
  if (daysRemaining < 0) {
    final elapsed = daysRemaining.abs();
    return 'Expired $elapsed day${elapsed == 1 ? '' : 's'} ago';
  }
  if (daysRemaining == 0) return 'Expires today';
  return '$daysRemaining day${daysRemaining == 1 ? '' : 's'} remaining';
}
