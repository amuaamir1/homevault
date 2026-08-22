import 'package:flutter/material.dart';

import '../../models/admin_feedback.dart';
import '../../models/beta_feedback.dart';
import '../../services/feedback_admin_service.dart';
import 'feedback_detail_screen.dart';

class FeedbackDashboardScreen extends StatefulWidget {
  const FeedbackDashboardScreen({
    super.key,
    required this.adminUid,
    this.repository,
  });

  final String adminUid;
  final FeedbackAdminRepository? repository;

  @override
  State<FeedbackDashboardScreen> createState() =>
      _FeedbackDashboardScreenState();
}

class _FeedbackDashboardScreenState extends State<FeedbackDashboardScreen> {
  late final FeedbackAdminRepository _repository;
  late final Future<bool> _adminCheck;
  Stream<List<AdminFeedbackItem>>? _feedbackStream;
  final _searchController = TextEditingController();

  String _query = '';
  _FeedbackStatusFilter _statusFilter = _FeedbackStatusFilter.open;
  FeedbackCategory? _categoryFilter;
  FeedbackPriority? _priorityFilter;
  _FeedbackSort _sort = _FeedbackSort.newest;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseFeedbackAdminRepository();
    _adminCheck = _repository.isAdmin(widget.adminUid);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback dashboard')),
      body: FutureBuilder<bool>(
        future: _adminCheck,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) {
            return const _AccessDenied();
          }

          _feedbackStream ??= _repository.watchFeedback();
          return StreamBuilder<List<AdminFeedbackItem>>(
            stream: _feedbackStream,
            builder: (context, feedbackSnapshot) {
              if (feedbackSnapshot.hasError) {
                return const _FeedbackLoadError();
              }
              if (!feedbackSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allItems = feedbackSnapshot.data!;
              final items = _filteredItems(allItems);
              final hasSearchOrFilters =
                  _query.trim().isNotEmpty ||
                  _statusFilter != _FeedbackStatusFilter.all ||
                  _categoryFilter != null ||
                  _priorityFilter != null;

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _feedbackStream = _repository.watchFeedback();
                  });
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _Summary(
                      items: allItems,
                      selectedFilter: _statusFilter,
                      onFilterSelected: (filter) =>
                          setState(() => _statusFilter = filter),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Search feedback',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        suffixIcon: _query.trim().isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Filters(
                      status: _statusFilter,
                      category: _categoryFilter,
                      priority: _priorityFilter,
                      onStatusChanged: (value) =>
                          setState(() => _statusFilter = value),
                      onCategoryChanged: (value) =>
                          setState(() => _categoryFilter = value),
                      onPriorityChanged: (value) =>
                          setState(() => _priorityFilter = value),
                      onClear: _hasFilters ? _clearFilters : null,
                    ),
                    const SizedBox(height: 14),
                    _ResultsHeader(
                      visibleCount: items.length,
                      totalCount: allItems.length,
                      sort: _sort,
                      onSortChanged: (value) => setState(() => _sort = value),
                    ),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      _NoFeedback(
                        hasAnyFeedback: allItems.isNotEmpty,
                        hasSearchOrFilters: hasSearchOrFilters,
                        onClear: hasSearchOrFilters
                            ? _clearSearchAndFilters
                            : null,
                      )
                    else
                      ...items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _FeedbackCard(
                            item: item,
                            onTap: () => _openDetails(item),
                            onStatusChanged: (status) =>
                                _quickStatus(item, status),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  bool get _hasFilters =>
      _statusFilter != _FeedbackStatusFilter.open ||
      _categoryFilter != null ||
      _priorityFilter != null;

  void _clearFilters() {
    setState(() {
      _statusFilter = _FeedbackStatusFilter.open;
      _categoryFilter = null;
      _priorityFilter = null;
    });
  }

  void _clearSearchAndFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _statusFilter = _FeedbackStatusFilter.open;
      _categoryFilter = null;
      _priorityFilter = null;
    });
  }

  List<AdminFeedbackItem> _filteredItems(List<AdminFeedbackItem> allItems) {
    final terms = _query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();

    final items = allItems.where((item) {
      if (!_statusFilter.matches(item.status)) {
        return false;
      }
      if (_categoryFilter != null && item.category != _categoryFilter) {
        return false;
      }
      if (_priorityFilter != null && item.priority != _priorityFilter) {
        return false;
      }
      if (terms.isEmpty) {
        return true;
      }

      final haystack = [
        item.message,
        item.uid,
        item.userEmail,
        item.category.label,
        item.status.label,
        item.priority.label,
        item.appVersion,
        item.buildNumber,
        item.releaseNumber,
        item.deviceManufacturer,
        item.deviceModel,
        item.androidVersion,
      ].join(' ').toLowerCase();

      return terms.every(haystack.contains);
    }).toList();

    items.sort((a, b) {
      return switch (_sort) {
        _FeedbackSort.newest => b.createdAt.compareTo(a.createdAt),
        _FeedbackSort.oldest => a.createdAt.compareTo(b.createdAt),
        _FeedbackSort.priority =>
          a.priority.sortRank != b.priority.sortRank
              ? a.priority.sortRank.compareTo(b.priority.sortRank)
              : b.createdAt.compareTo(a.createdAt),
      };
    });

    return items;
  }

  Future<void> _openDetails(AdminFeedbackItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FeedbackDetailScreen(
          item: item,
          adminUid: widget.adminUid,
          repository: _repository,
        ),
      ),
    );
  }

  Future<void> _quickStatus(
    AdminFeedbackItem item,
    FeedbackWorkflowStatus status,
  ) async {
    try {
      await _repository.updateFeedback(
        item: item,
        adminUid: widget.adminUid,
        status: status,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback could not be updated.')),
      );
    }
  }
}

enum _FeedbackStatusFilter {
  open,
  all,
  newFeedback,
  inReview,
  planned,
  resolved,
  dismissed,
}

extension on _FeedbackStatusFilter {
  String get label => switch (this) {
    _FeedbackStatusFilter.open => 'Open',
    _FeedbackStatusFilter.all => 'All',
    _FeedbackStatusFilter.newFeedback => 'New',
    _FeedbackStatusFilter.inReview => 'In review',
    _FeedbackStatusFilter.planned => 'Planned',
    _FeedbackStatusFilter.resolved => 'Resolved',
    _FeedbackStatusFilter.dismissed => 'Dismissed',
  };

  bool matches(FeedbackWorkflowStatus status) => switch (this) {
    _FeedbackStatusFilter.open =>
      status != FeedbackWorkflowStatus.resolved &&
          status != FeedbackWorkflowStatus.dismissed,
    _FeedbackStatusFilter.all => true,
    _FeedbackStatusFilter.newFeedback =>
      status == FeedbackWorkflowStatus.newFeedback,
    _FeedbackStatusFilter.inReview => status == FeedbackWorkflowStatus.inReview,
    _FeedbackStatusFilter.planned => status == FeedbackWorkflowStatus.planned,
    _FeedbackStatusFilter.resolved => status == FeedbackWorkflowStatus.resolved,
    _FeedbackStatusFilter.dismissed =>
      status == FeedbackWorkflowStatus.dismissed,
  };
}

enum _FeedbackSort { newest, oldest, priority }

extension on _FeedbackSort {
  String get label => switch (this) {
    _FeedbackSort.newest => 'Newest first',
    _FeedbackSort.oldest => 'Oldest first',
    _FeedbackSort.priority => 'Priority',
  };
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.items,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final List<AdminFeedbackItem> items;
  final _FeedbackStatusFilter selectedFilter;
  final ValueChanged<_FeedbackStatusFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    int count(FeedbackWorkflowStatus status) =>
        items.where((item) => item.status == status).length;

    final openCount = items
        .where(
          (item) =>
              item.status != FeedbackWorkflowStatus.resolved &&
              item.status != FeedbackWorkflowStatus.dismissed,
        )
        .length;

    final metrics = [
      _MetricData(
        label: 'Open',
        value: openCount,
        icon: Icons.inbox_outlined,
        filter: _FeedbackStatusFilter.open,
      ),
      _MetricData(
        label: 'New',
        value: count(FeedbackWorkflowStatus.newFeedback),
        icon: Icons.fiber_new_outlined,
        filter: _FeedbackStatusFilter.newFeedback,
      ),
      _MetricData(
        label: 'In review',
        value: count(FeedbackWorkflowStatus.inReview),
        icon: Icons.manage_search_outlined,
        filter: _FeedbackStatusFilter.inReview,
      ),
      _MetricData(
        label: 'Resolved',
        value: count(FeedbackWorkflowStatus.resolved),
        icon: Icons.task_alt_outlined,
        filter: _FeedbackStatusFilter.resolved,
      ),
    ];

    return Row(
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          if (index > 0) const SizedBox(width: 6),
          Expanded(
            child: _Metric(
              data: metrics[index],
              selected: selectedFilter == metrics[index].filter,
              onTap: () => onFilterSelected(metrics[index].filter),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.filter,
  });

  final String label;
  final int value;
  final IconData icon;
  final _FeedbackStatusFilter filter;
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _MetricData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: selected ? colors.primaryContainer : null,
      child: InkWell(
        key: ValueKey('feedback-summary-${data.filter.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    data.icon,
                    size: 16,
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${data.value}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? colors.onPrimaryContainer : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : null,
                  color: selected ? colors.onPrimaryContainer : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.status,
    required this.category,
    required this.priority,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onPriorityChanged,
    required this.onClear,
  });

  final _FeedbackStatusFilter status;
  final FeedbackCategory? category;
  final FeedbackPriority? priority;
  final ValueChanged<_FeedbackStatusFilter> onStatusChanged;
  final ValueChanged<FeedbackCategory?> onCategoryChanged;
  final ValueChanged<FeedbackPriority?> onPriorityChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    InputDecoration decoration(String label) => InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.fromLTRB(9, 9, 5, 9),
    );

    final statusField = DropdownButtonFormField<_FeedbackStatusFilter>(
      key: ValueKey('feedback-status-${status.name}'),
      initialValue: status,
      isExpanded: true,
      iconSize: 18,
      decoration: decoration('Status'),
      items: _FeedbackStatusFilter.values
          .map(
            (value) => DropdownMenuItem<_FeedbackStatusFilter>(
              value: value,
              child: Text(value.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value != null) onStatusChanged(value);
      },
    );

    final categoryField = DropdownButtonFormField<FeedbackCategory?>(
      key: ValueKey('feedback-category-${category?.name ?? 'all'}'),
      initialValue: category,
      isExpanded: true,
      iconSize: 18,
      decoration: decoration('Category'),
      items: [
        const DropdownMenuItem<FeedbackCategory?>(
          value: null,
          child: Text('All', overflow: TextOverflow.ellipsis),
        ),
        ...FeedbackCategory.values.map(
          (value) => DropdownMenuItem<FeedbackCategory?>(
            value: value,
            child: Text(value.label, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onCategoryChanged,
    );

    final priorityField = DropdownButtonFormField<FeedbackPriority?>(
      key: ValueKey('feedback-priority-${priority?.name ?? 'all'}'),
      initialValue: priority,
      isExpanded: true,
      iconSize: 18,
      decoration: decoration('Priority'),
      items: [
        const DropdownMenuItem<FeedbackPriority?>(
          value: null,
          child: Text('All', overflow: TextOverflow.ellipsis),
        ),
        ...FeedbackPriority.values.map(
          (value) => DropdownMenuItem<FeedbackPriority?>(
            value: value,
            child: Text(value.label, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onPriorityChanged,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: statusField),
            const SizedBox(width: 6),
            Expanded(child: categoryField),
            const SizedBox(width: 6),
            Expanded(child: priorityField),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Clear filters',
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.visibleCount,
    required this.totalCount,
    required this.sort,
    required this.onSortChanged,
  });

  final int visibleCount;
  final int totalCount;
  final _FeedbackSort sort;
  final ValueChanged<_FeedbackSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final countLabel = visibleCount == totalCount
        ? '$visibleCount feedback ${visibleCount == 1 ? 'item' : 'items'}'
        : 'Showing $visibleCount of $totalCount';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feedback',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(countLabel, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        PopupMenuButton<_FeedbackSort>(
          tooltip: 'Sort feedback',
          initialValue: sort,
          onSelected: onSortChanged,
          itemBuilder: (context) => _FeedbackSort.values
              .map(
                (value) =>
                    PopupMenuItem(value: value, child: Text(value.label)),
              )
              .toList(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort, size: 20),
                const SizedBox(width: 6),
                Text(sort.label),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.item,
    required this.onTap,
    required this.onStatusChanged,
  });

  final AdminFeedbackItem item;
  final VoidCallback onTap;
  final ValueChanged<FeedbackWorkflowStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Tag(label: item.status.label),
                        _Tag(label: item.priority.label),
                        _Tag(label: item.category.label),
                        if (item.hasScreenshot)
                          const _Tag(
                            label: 'Screenshot',
                            icon: Icons.image_outlined,
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<FeedbackWorkflowStatus>(
                    tooltip: 'Change status',
                    onSelected: onStatusChanged,
                    itemBuilder: (context) => FeedbackWorkflowStatus.values
                        .map(
                          (status) => PopupMenuItem(
                            value: status,
                            child: Text(status.label),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      item.submitterLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _shortDate(item.createdAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              if (item.appVersion.trim().isNotEmpty ||
                  item.deviceModel.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  [
                    if (item.appVersion.trim().isNotEmpty)
                      'v${item.appVersion.trim()}',
                    if (item.deviceModel.trim().isNotEmpty)
                      item.deviceModel.trim(),
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _shortDate(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 4)],
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'This dashboard is available only to HomeVault administrators.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _FeedbackLoadError extends StatelessWidget {
  const _FeedbackLoadError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Feedback could not be loaded. Check the Firestore rules and admin access.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _NoFeedback extends StatelessWidget {
  const _NoFeedback({
    required this.hasAnyFeedback,
    required this.hasSearchOrFilters,
    required this.onClear,
  });

  final bool hasAnyFeedback;
  final bool hasSearchOrFilters;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final isFilteredEmpty = hasAnyFeedback && hasSearchOrFilters;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
        child: Column(
          children: [
            Icon(
              isFilteredEmpty
                  ? Icons.search_off_outlined
                  : Icons.inbox_outlined,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              isFilteredEmpty ? 'No feedback found' : 'No feedback yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              isFilteredEmpty
                  ? 'Try changing the search or filters.'
                  : 'New beta feedback will appear here automatically.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (onClear != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onClear,
                child: const Text('Clear search & filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
