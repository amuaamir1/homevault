import 'package:flutter/material.dart';

import '../../models/global_search_result.dart';
import '../../services/global_search_service.dart';
import '../../state/app_scope.dart';
import '../../widgets/empty_state.dart';
import '../appliances/appliance_details_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  GlobalSearchFilter _filter = GlobalSearchFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openResult(GlobalSearchResult result) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            ApplianceDetailsScreen(applianceId: result.applianceId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final query = _searchController.text;
    final results = const GlobalSearchService().search(
      appliances: store.appliances,
      query: query,
      filter: _filter,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Global search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const Key('globalSearchField'),
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Search HomeVault',
                hintText: 'Appliance, serial, document, claim, service...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: GlobalSearchFilter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = GlobalSearchFilter.values[index];
                return FilterChip(
                  label: Text(filter.label),
                  selected: _filter == filter,
                  onSelected: (_) {
                    setState(() => _filter = filter);
                  },
                );
              },
            ),
          ),
          Expanded(
            child: query.trim().isEmpty
                ? const _SearchStartState()
                : results.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_outlined,
                    title: 'No matching records',
                    message:
                        'Try another keyword or select a different search filter.',
                    actionLabel: 'Clear search',
                    onAction: () async {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : ListView.separated(
                    key: const Key('globalSearchResults'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final result = results[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(_iconFor(result.type)),
                          ),
                          title: Text(result.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 3),
                              Text(
                                result.type.label,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                result.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openResult(result),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(GlobalSearchResultType type) {
    return switch (type) {
      GlobalSearchResultType.appliance => Icons.devices_other_outlined,
      GlobalSearchResultType.document => Icons.description_outlined,
      GlobalSearchResultType.support => Icons.support_agent_outlined,
      GlobalSearchResultType.warranty => Icons.verified_user_outlined,
      GlobalSearchResultType.service => Icons.build_outlined,
    };
  }
}

class _SearchStartState extends StatelessWidget {
  const _SearchStartState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.manage_search_outlined,
      title: 'Search everything in HomeVault',
      message:
          'Find appliances, model and serial numbers, documents, support contacts, warranty claims, and service records.',
    );
  }
}
