import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../models/appliance.dart';
import '../../models/document_form_result.dart';
import '../../models/stored_document.dart';
import '../../services/document_storage_service.dart';
import '../../services/document_vault_service.dart';
import '../../services/homevault_error_presenter.dart';
import '../../state/app_scope.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stored_document_tile.dart';
import 'add_document_screen.dart';
import 'document_details_screen.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, this.initialApplianceId});

  final String? initialApplianceId;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _vaultService = const DocumentVaultService();
  final _searchController = TextEditingController();

  String _query = '';
  String? _selectedApplianceId;
  DocumentVaultCategory? _selectedCategory;
  DocumentType? _selectedType;
  DocumentVaultAvailability _availability = DocumentVaultAvailability.all;
  DocumentVaultSort _sort = DocumentVaultSort.newest;

  @override
  void initState() {
    super.initState();
    _selectedApplianceId = widget.initialApplianceId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Future<void> _openDocument(
    BuildContext context,
    String applianceId,
    StoredDocument document,
  ) async {
    var availableDocument = document;

    if (!availableDocument.isAvailableOnDevice) {
      if (!availableDocument.isAvailableInCloud) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This document file is unavailable. Edit the document and choose the file again.',
            ),
          ),
        );
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Preparing document...'),
          duration: Duration(seconds: 30),
        ),
      );

      try {
        availableDocument = await AppScope.read(
          context,
        ).downloadDocument(applianceId, document.id);
      } catch (error) {
        messenger.hideCurrentSnackBar();
        if (!context.mounted) return;
        showHomeVaultError(
          context,
          error,
          fallback: 'The document could not be prepared right now.',
          actionLabel: 'Retry',
          onAction: () => _openDocument(context, applianceId, document),
        );
        return;
      }

      messenger.hideCurrentSnackBar();
    }

    try {
      await OpenFilex.open(availableDocument.localPath);
    } catch (error) {
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The document could not be opened on this device.',
      );
    }
  }

  Future<void> _addDocument(BuildContext context) async {
    final store = AppScope.read(context);
    if (store.appliances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an appliance before adding documents.'),
        ),
      );
      return;
    }

    final selectedApplianceId =
        store.appliances.any((item) => item.id == _selectedApplianceId)
        ? _selectedApplianceId
        : null;

    final result = await Navigator.of(context).push<DocumentFormResult>(
      MaterialPageRoute(
        builder: (context) => AddDocumentScreen(
          appliances: store.appliances.toList(growable: false),
          initialApplianceId: selectedApplianceId,
          initialType: _selectedType,
        ),
      ),
    );

    if (result == null || !context.mounted) return;

    try {
      await AppScope.read(
        context,
      ).addDocument(result.applianceId, result.document);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.document.displayTitle} was saved.')),
      );
    } catch (error) {
      try {
        await DocumentStorageService().deleteStoredDocument(result.document);
      } catch (_) {
        // Preserve the original save error if temporary-file cleanup fails.
      }
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The document could not be saved. Please try again.',
      );
    }
  }

  Future<void> _editDocument(
    BuildContext context,
    DocumentVaultEntry entry,
  ) async {
    final store = AppScope.read(context);
    final result = await Navigator.of(context).push<DocumentFormResult>(
      MaterialPageRoute(
        builder: (context) => AddDocumentScreen(
          appliances: store.appliances.toList(growable: false),
          initialApplianceId: entry.appliance.id,
          document: entry.document,
        ),
      ),
    );

    if (result == null || !context.mounted) return;

    try {
      await AppScope.read(
        context,
      ).replaceDocument(result.applianceId, entry.document.id, result.document);

      if (result.replacedFile && result.originalDocument != null) {
        try {
          await DocumentStorageService().deleteStoredDocument(
            result.originalDocument!,
          );
        } catch (_) {
          // The saved metadata is correct even if an old file remains.
        }
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.document.displayTitle} was updated.')),
      );
    } catch (error) {
      if (result.replacedFile) {
        try {
          await DocumentStorageService().deleteStoredDocument(result.document);
        } catch (_) {
          // Preserve the update error if replacement-file cleanup fails.
        }
      }
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The document could not be updated. Please try again.',
      );
    }
  }

  Future<void> _deleteDocument(
    BuildContext context,
    DocumentVaultEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(
          'This will permanently remove ${entry.document.displayTitle} from ${entry.appliance.name}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await AppScope.read(
        context,
      ).removeDocument(entry.appliance.id, entry.document.id);
      try {
        await DocumentStorageService().deleteStoredDocument(entry.document);
      } catch (_) {
        // The saved record is already correct if physical cleanup fails.
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Document deleted.')));
    } catch (error) {
      if (!context.mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The document could not be deleted. Please try again.',
      );
    }
  }

  Future<void> _showDetails(
    BuildContext context,
    DocumentVaultEntry entry,
  ) async {
    final action = await Navigator.of(context).push<DocumentDetailsAction>(
      MaterialPageRoute(
        builder: (context) => DocumentDetailsScreen(
          appliance: entry.appliance,
          document: entry.document,
        ),
      ),
    );

    if (action == null || !context.mounted) return;
    switch (action) {
      case DocumentDetailsAction.open:
        await _openDocument(context, entry.appliance.id, entry.document);
        break;
      case DocumentDetailsAction.edit:
        await _editDocument(context, entry);
        break;
      case DocumentDetailsAction.delete:
        await _deleteDocument(context, entry);
        break;
    }
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _selectedApplianceId = null;
      _selectedCategory = null;
      _selectedType = null;
      _availability = DocumentVaultAvailability.all;
      _sort = DocumentVaultSort.newest;
    });
  }

  Future<void> _showApplianceFilter(List<Appliance> appliances) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Filter by appliance')),
            ListTile(
              leading: const Icon(Icons.select_all),
              title: const Text('All appliances'),
              trailing: _selectedApplianceId == null
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                setState(() => _selectedApplianceId = null);
                Navigator.of(sheetContext).pop();
              },
            ),
            ...appliances.map(
              (appliance) => ListTile(
                leading: const Icon(Icons.home_repair_service_outlined),
                title: Text(appliance.name),
                subtitle: Text('${appliance.brand} • ${appliance.category}'),
                trailing: _selectedApplianceId == appliance.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  setState(() => _selectedApplianceId = appliance.id);
                  Navigator.of(sheetContext).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTypeFilter() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Filter by document type')),
            ListTile(
              title: const Text('All document types'),
              trailing: _selectedType == null ? const Icon(Icons.check) : null,
              onTap: () {
                setState(() => _selectedType = null);
                Navigator.of(sheetContext).pop();
              },
            ),
            ...DocumentVaultService.supportedTypes.map(
              (type) => ListTile(
                title: Text(type.label),
                trailing: _selectedType == type
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  setState(() => _selectedType = type);
                  Navigator.of(sheetContext).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAvailabilityFilter() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Filter by availability')),
            ...DocumentVaultAvailability.values.map(
              (availability) => ListTile(
                title: Text(availability.label),
                trailing: _availability == availability
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  setState(() => _availability = availability);
                  Navigator.of(sheetContext).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSort() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Sort documents')),
            ...DocumentVaultSort.values.map(
              (sort) => ListTile(
                title: Text(sort.label),
                trailing: _sort == sort ? const Icon(Icons.check) : null,
                onTap: () {
                  setState(() => _sort = sort);
                  Navigator.of(sheetContext).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appliances = AppScope.of(context).appliances.toList(growable: false);
    final entries = _vaultService.entries(appliances);
    final summary = _vaultService.summarize(entries);
    final effectiveApplianceId =
        appliances.any((item) => item.id == _selectedApplianceId)
        ? _selectedApplianceId
        : null;
    final filter = DocumentVaultFilter(
      query: _query,
      applianceId: effectiveApplianceId,
      category: _selectedCategory,
      type: _selectedType,
      availability: _availability,
      sort: _sort,
    );
    final filtered = _vaultService.filterAndSort(entries, filter);
    final selectedAppliance = effectiveApplianceId == null
        ? null
        : appliances.firstWhere((item) => item.id == effectiveApplianceId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          if (filter.hasFilters)
            IconButton(
              key: const ValueKey('documentVaultClearFilters'),
              tooltip: 'Clear filters',
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'documents_add_fab',
        onPressed: () => _addDocument(context),
        icon: const Icon(Icons.add),
        label: const Text('Add document'),
      ),
      body: entries.isEmpty
          ? EmptyState(
              icon: Icons.folder_copy_outlined,
              title: 'Your document vault is empty',
              message:
                  'Add invoices, warranty cards, manuals, service receipts, service reports, and installation reports.',
              actionLabel: 'Add document',
              onAction: () => _addDocument(context),
            )
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: SearchBar(
                      key: const ValueKey('documentVaultSearch'),
                      controller: _searchController,
                      hintText: 'Search title, appliance, brand, reference...',
                      leading: const Icon(Icons.search),
                      trailing: _query.isEmpty
                          ? null
                          : [
                              IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close),
                              ),
                            ],
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _VaultMetric(
                            key: const ValueKey('documentVaultTotalMetric'),
                            label: 'Documents',
                            value: '${summary.totalDocuments}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _VaultMetric(
                            key: const ValueKey('documentVaultApplianceMetric'),
                            label: 'Appliances',
                            value: '${summary.appliancesWithDocuments}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _VaultMetric(
                            key: const ValueKey(
                              'documentVaultUnavailableMetric',
                            ),
                            label: 'Unavailable',
                            value: '${summary.unavailableDocuments}',
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        ChoiceChip(
                          key: const ValueKey('documentVaultCategory_all'),
                          label: const Text('All categories'),
                          selected: _selectedCategory == null,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = null),
                        ),
                        const SizedBox(width: 8),
                        ...DocumentVaultCategory.values.map(
                          (category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              key: ValueKey(
                                'documentVaultCategory_${category.name}',
                              ),
                              label: Text(category.label),
                              selected: _selectedCategory == category,
                              onSelected: (_) =>
                                  setState(() => _selectedCategory = category),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 46,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      children: [
                        ActionChip(
                          key: const ValueKey('documentVaultApplianceFilter'),
                          avatar: const Icon(
                            Icons.home_repair_service_outlined,
                          ),
                          label: Text(selectedAppliance?.name ?? 'Appliance'),
                          onPressed: () => _showApplianceFilter(appliances),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          key: const ValueKey('documentVaultTypeFilter'),
                          avatar: const Icon(Icons.description_outlined),
                          label: Text(_selectedType?.label ?? 'Type'),
                          onPressed: _showTypeFilter,
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          key: const ValueKey(
                            'documentVaultAvailabilityFilter',
                          ),
                          avatar: const Icon(Icons.cloud_outlined),
                          label: Text(
                            _availability == DocumentVaultAvailability.all
                                ? 'Availability'
                                : _availability.label,
                          ),
                          onPressed: _showAvailabilityFilter,
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          key: const ValueKey('documentVaultSort'),
                          avatar: const Icon(Icons.sort),
                          label: Text(_sort.label),
                          onPressed: _showSort,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off,
                            title: 'No matching documents',
                            message:
                                'Try another search, category, appliance, type, or availability filter.',
                            actionLabel: filter.hasFilters
                                ? 'Clear filters'
                                : null,
                            onAction: filter.hasFilters
                                ? () async => _clearFilters()
                                : null,
                          )
                        : ListView.separated(
                            key: const ValueKey('documentVaultList'),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final entry = filtered[index];
                              return Card(
                                key: ValueKey(
                                  'documentVaultCard_${entry.document.id}',
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: StoredDocumentTile(
                                    document: entry.document,
                                    title: entry.document.displayTitle,
                                    subtitle:
                                        '${entry.document.type.label} • ${entry.appliance.name} • ${_date(entry.document.attachedAt)}',
                                    onOpen: () => _openDocument(
                                      context,
                                      entry.appliance.id,
                                      entry.document,
                                    ),
                                    onDetails: () =>
                                        _showDetails(context, entry),
                                    onEdit: () => _editDocument(context, entry),
                                    onDelete: () =>
                                        _deleteDocument(context, entry),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _VaultMetric extends StatelessWidget {
  const _VaultMetric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
