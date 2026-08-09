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
  FeedbackWorkflowStatus? _statusFilter;
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
                  _query.trim().isNotEmpty || _hasFilters;

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _feedbackStream = _repository.watchFeedback();
                  });
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _Summary(items: allItems),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Search feedback',
                        prefixIcon: const Icon(Icons.search),
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
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 18),
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
      _statusFilter != null ||
      _categoryFilter != null ||
      _priorityFilter != null;

  void _clearFilters() {
    setState(() {
      _statusFilter = null;
      _categoryFilter = null;
      _priorityFilter = null;
    });
  }

  void _clearSearchAndFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _statusFilter = null;
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
      if (_statusFilter != null && item.status != _statusFilter) {
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

enum _FeedbackSort { newest, oldest, priority }

extension on _FeedbackSort {
  String get label => switch (this) {
    _FeedbackSort.newest => 'Newest first',
    _FeedbackSort.oldest => 'Oldest first',
    _FeedbackSort.priority => 'Priority',
  };
}

class _Summary extends StatelessWidget {
  const _Summary({required this.items});

  final List<AdminFeedbackItem> items;

  @override
  Widget build(BuildContext context) {
    int count(FeedbackWorkflowStatus status) =>
        items.where((item) => item.status == status).length;

    final metrics = [
      _MetricData(
        label: 'Total',
        value: items.length,
        icon: Icons.feedback_outlined,
      ),
      _MetricData(
        label: 'New',
        value: count(FeedbackWorkflowStatus.newFeedback),
        icon: Icons.fiber_new_outlined,
      ),
      _MetricData(
        label: 'In review',
        value: count(FeedbackWorkflowStatus.inReview),
        icon: Icons.manage_search_outlined,
      ),
      _MetricData(
        label: 'Resolved',
        value: count(FeedbackWorkflowStatus.resolved),
        icon: Icons.task_alt_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        final aspectRatio = constraints.maxWidth < 420 ? 1.85 : 2.25;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) => _Metric(data: metrics[index]),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;
}

class _Metric extends StatelessWidget {
  const _Metric({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                data.icon,
                size: 20,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data.value}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
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

  final FeedbackWorkflowStatus? status;
  final FeedbackCategory? category;
  final FeedbackPriority? priority;
  final ValueChanged<FeedbackWorkflowStatus?> onStatusChanged;
  final ValueChanged<FeedbackCategory?> onCategoryChanged;
  final ValueChanged<FeedbackPriority?> onPriorityChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Filters',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (onClear != null)
                  TextButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ),
            const SizedBox(height: 4),
            Text('Status', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: status == null,
                  onSelected: (_) => onStatusChanged(null),
                ),
                ...FeedbackWorkflowStatus.values.map(
                  (value) => ChoiceChip(
                    label: Text(value.label),
                    selected: status == value,
                    onSelected: (_) => onStatusChanged(value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final stackFilters = constraints.maxWidth < 640;

                final categoryField =
                    DropdownButtonFormField<FeedbackCategory?>(
                      key: ValueKey(
                        'feedback-category-${category?.name ?? 'all'}',
                      ),
                      initialValue: category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        const DropdownMenuItem<FeedbackCategory?>(
                          value: null,
                          child: Text('All categories'),
                        ),
                        ...FeedbackCategory.values.map(
                          (value) => DropdownMenuItem<FeedbackCategory?>(
                            value: value,
                            child: Text(
                              value.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: onCategoryChanged,
                    );

                final priorityField =
                    DropdownButtonFormField<FeedbackPriority?>(
                      key: ValueKey(
                        'feedback-priority-${priority?.name ?? 'all'}',
                      ),
                      initialValue: priority,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: [
                        const DropdownMenuItem<FeedbackPriority?>(
                          value: null,
                          child: Text('All priorities'),
                        ),
                        ...FeedbackPriority.values.map(
                          (value) => DropdownMenuItem<FeedbackPriority?>(
                            value: value,
                            child: Text(
                              value.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: onPriorityChanged,
                    );

                if (stackFilters) {
                  return Column(
                    children: [
                      categoryField,
                      const SizedBox(height: 10),
                      priorityField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: categoryField),
                    const SizedBox(width: 10),
                    Expanded(child: priorityField),
                  ],
                );
              },
            ),
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
