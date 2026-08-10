import 'package:flutter/material.dart';

import '../../models/appliance.dart';
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

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
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
          onRefresh: store.refresh,
          child: ListView(
            key: const Key('warrantyCenterList'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _WarrantySummary(
                store: store,
                now: now,
                selectedFilter: _filter,
                onSelected: (filter) {
                  setState(() {
                    _filter = _filter == filter ? WarrantyFilter.all : filter;
                  });
                },
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 14),
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
}

class _WarrantySummary extends StatelessWidget {
  const _WarrantySummary({
    required this.store,
    required this.now,
    required this.selectedFilter,
    required this.onSelected,
  });

  final ApplianceStore store;
  final DateTime now;
  final WarrantyFilter selectedFilter;
  final ValueChanged<WarrantyFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Active',
        store.warrantyCount(WarrantyStatus.active, now: now),
        AppColors.success,
        WarrantyFilter.active,
        const ValueKey('warrantySummaryActive'),
      ),
      (
        'Expiring',
        store.warrantyCount(WarrantyStatus.expiringSoon, now: now),
        AppColors.warning,
        WarrantyFilter.expiringSoon,
        const ValueKey('warrantySummaryExpiring'),
      ),
      (
        'Expired',
        store.warrantyCount(WarrantyStatus.expired, now: now),
        AppColors.danger,
        WarrantyFilter.expired,
        const ValueKey('warrantySummaryExpired'),
      ),
      (
        'No date',
        store.warrantyCount(WarrantyStatus.notProvided, now: now),
        AppColors.textSecondary,
        WarrantyFilter.notProvided,
        const ValueKey('warrantySummaryNoDate'),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items
            .map((item) {
              final selected = selectedFilter == item.$4;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _WarrantyStatPill(
                  key: item.$5,
                  label: item.$1,
                  count: item.$2,
                  color: item.$3,
                  selected: selected,
                  onTap: () => onSelected(item.$4),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _WarrantyStatPill extends StatelessWidget {
  const _WarrantyStatPill({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label warranties: $count',
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.14)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? color.withValues(alpha: 0.5)
                : colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 5),
                  Icon(Icons.check, size: 15, color: color),
                ],
              ],
            ),
          ),
        ),
      ),
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
              if (appliance.warrantyDurationLabel.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.timelapse_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Warranty duration: ${appliance.warrantyDurationLabel}',
                      ),
                    ),
                  ],
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
