import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/appliance.dart';
import '../../models/appliance_form_result.dart';
import '../../services/document_storage_service.dart';
import '../../services/support_action_service.dart';
import '../../state/app_scope.dart';
import '../../widgets/empty_state.dart';
import '../appliances/add_appliance_screen.dart';

enum _SupportFilter {
  all('All'),
  phone('Phone'),
  email('Email'),
  website('Website');

  const _SupportFilter(this.label);

  final String label;
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _searchController = TextEditingController();
  final _actionService = const SupportActionService();
  _SupportFilter _filter = _SupportFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on SupportActionException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  bool _matchesFilter(Appliance appliance) {
    return switch (_filter) {
      _SupportFilter.all => true,
      _SupportFilter.phone => appliance.supportPhone.trim().isNotEmpty,
      _SupportFilter.email => appliance.supportEmail.trim().isNotEmpty,
      _SupportFilter.website => appliance.supportWebsite.trim().isNotEmpty,
    };
  }

  bool _matchesSearch(Appliance appliance) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;

    final searchableText = [
      appliance.name,
      appliance.category,
      appliance.brand,
      appliance.modelNumber,
      appliance.serialNumber,
      appliance.supportProvider,
      appliance.supportPhone,
      appliance.supportEmail,
      appliance.supportWebsite,
      appliance.supportNotes,
    ].join(' ').toLowerCase();

    return searchableText.contains(query);
  }

  Future<void> _editAppliance(BuildContext context, Appliance appliance) async {
    final result = await Navigator.of(context).push<ApplianceFormResult>(
      MaterialPageRoute(
        builder: (context) => AddApplianceScreen(appliance: appliance),
      ),
    );

    if (result == null || !context.mounted) return;

    try {
      await AppScope.read(context).update(result.appliance);

      for (final document in result.documentsToDelete) {
        try {
          await DocumentStorageService().deleteStoredDocument(document);
        } catch (_) {
          // The record was updated; stale files can be cleaned later.
        }
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.appliance.name} was updated.')),
      );
    } catch (_) {
      for (final document in result.documentsAdded) {
        try {
          await DocumentStorageService().deleteStoredDocument(document);
        } catch (_) {
          // Preserve the original save error if cleanup also fails.
        }
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The support details could not be saved.'),
        ),
      );
    }
  }

  Future<void> _chooseAppliance(BuildContext context) async {
    final appliances = AppScope.read(context).appliances.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (appliances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an appliance before adding support details.'),
        ),
      );
      return;
    }

    final selectedId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose an appliance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: appliances.length,
                itemBuilder: (context, index) {
                  final appliance = appliances[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.devices_other),
                    ),
                    title: Text(appliance.name),
                    subtitle: Text(
                      appliance.brand.trim().isEmpty
                          ? appliance.category
                          : appliance.brand,
                    ),
                    trailing: appliance.hasSupportDetails
                        ? const Icon(Icons.check_circle_outline)
                        : const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pop(appliance.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedId == null || !context.mounted) return;
    final appliance = AppScope.read(context).applianceById(selectedId);
    if (appliance != null) {
      await _editAppliance(context, appliance);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allAppliances = AppScope.of(context).appliances;
    final supportAppliances =
        allAppliances
            .where((appliance) => appliance.hasSupportDetails)
            .where(_matchesFilter)
            .where(_matchesSearch)
            .toList(growable: false)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer support'),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
      floatingActionButton: allAppliances.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'support_add_fab',
              onPressed: () => _chooseAppliance(context),
              icon: const Icon(Icons.contact_support_outlined),
              label: const Text('Add support details'),
            ),
      body: allAppliances.isEmpty
          ? const EmptyState(
              icon: Icons.support_agent,
              title: 'No appliances yet',
              message:
                  'Add an appliance first, then save its customer-care contact details here.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search appliance, brand, provider, or contact',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _SupportFilter.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _SupportFilter.values[index];
                      return FilterChip(
                        label: Text(filter.label),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: supportAppliances.isEmpty
                      ? EmptyState(
                          icon: Icons.contact_phone_outlined,
                          title:
                              _searchController.text.trim().isEmpty &&
                                  _filter == _SupportFilter.all
                              ? 'No support contacts yet'
                              : 'No matching support contacts',
                          message:
                              _searchController.text.trim().isEmpty &&
                                  _filter == _SupportFilter.all
                              ? 'Add a phone number, email address, or support website to an appliance.'
                              : 'Try another search term or contact filter.',
                          actionLabel:
                              _searchController.text.trim().isEmpty &&
                                  _filter == _SupportFilter.all
                              ? 'Choose appliance'
                              : null,
                          onAction:
                              _searchController.text.trim().isEmpty &&
                                  _filter == _SupportFilter.all
                              ? () => _chooseAppliance(context)
                              : null,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: supportAppliances.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final appliance = supportAppliances[index];
                            return _SupportCard(
                              appliance: appliance,
                              onCall: appliance.supportPhone.trim().isEmpty
                                  ? null
                                  : () => _runAction(
                                      context,
                                      () => _actionService.call(
                                        appliance.supportPhone,
                                      ),
                                    ),
                              onEmail: appliance.supportEmail.trim().isEmpty
                                  ? null
                                  : () => _runAction(
                                      context,
                                      () => _actionService.email(appliance),
                                    ),
                              onWebsite: appliance.supportWebsite.trim().isEmpty
                                  ? null
                                  : () => _runAction(
                                      context,
                                      () => _actionService.openWebsite(
                                        appliance.supportWebsite,
                                      ),
                                    ),
                              onCopy: (label, value) =>
                                  _copy(context, label, value),
                              onEdit: () => _editAppliance(context, appliance),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.appliance,
    required this.onCall,
    required this.onEmail,
    required this.onWebsite,
    required this.onCopy,
    required this.onEdit,
  });

  final Appliance appliance;
  final Future<void> Function()? onCall;
  final Future<void> Function()? onEmail;
  final Future<void> Function()? onWebsite;
  final Future<void> Function(String label, String value) onCopy;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    final provider = appliance.supportProvider.trim().isNotEmpty
        ? appliance.supportProvider
        : appliance.brand.trim().isNotEmpty
        ? appliance.brand
        : appliance.category;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Text(
                    appliance.name.trim().isEmpty
                        ? '?'
                        : appliance.name.trim()[0].toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appliance.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        provider,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit support details',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            if (appliance.supportNotes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(appliance.supportNotes),
              ),
            ],
            if (appliance.hasSupportAction) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onCall != null)
                    FilledButton.tonalIcon(
                      onPressed: onCall,
                      icon: const Icon(Icons.phone_outlined),
                      label: const Text('Call'),
                    ),
                  if (onEmail != null)
                    FilledButton.tonalIcon(
                      onPressed: onEmail,
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('Email'),
                    ),
                  if (onWebsite != null)
                    FilledButton.tonalIcon(
                      onPressed: onWebsite,
                      icon: const Icon(Icons.language),
                      label: const Text('Website'),
                    ),
                ],
              ),
            ],
            const Divider(height: 24),
            if (appliance.supportPhone.trim().isNotEmpty)
              _ContactRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: appliance.supportPhone,
                onCopy: onCopy,
              ),
            if (appliance.supportEmail.trim().isNotEmpty)
              _ContactRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: appliance.supportEmail,
                onCopy: onCopy,
              ),
            if (appliance.supportWebsite.trim().isNotEmpty)
              _ContactRow(
                icon: Icons.language,
                label: 'Website',
                value: appliance.supportWebsite,
                onCopy: onCopy,
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;
  final Future<void> Function(String label, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      trailing: IconButton(
        tooltip: 'Copy ${label.toLowerCase()}',
        onPressed: () => onCopy(label, value),
        icon: const Icon(Icons.copy_outlined),
      ),
    );
  }
}
