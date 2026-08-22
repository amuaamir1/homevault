import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../models/appliance.dart';
import '../../models/document_form_result.dart';
import '../../models/stored_document.dart';
import '../../services/document_storage_service.dart';
import '../../services/homevault_error_presenter.dart';
import '../../state/app_scope.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stored_document_tile.dart';
import 'add_document_screen.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String _query = '';
  DocumentType? _selectedType;

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

    final result = await Navigator.of(context).push<DocumentFormResult>(
      MaterialPageRoute(
        builder: (context) => AddDocumentScreen(
          appliances: store.appliances.toList(growable: false),
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

  Future<void> _editDocument(BuildContext context, _DocumentEntry entry) async {
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
    _DocumentEntry entry,
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

  @override
  Widget build(BuildContext context) {
    final entries = <_DocumentEntry>[];
    for (final appliance in AppScope.of(context).appliances) {
      for (final document in appliance.allDocuments) {
        entries.add(_DocumentEntry(appliance: appliance, document: document));
      }
    }

    final query = _query.trim().toLowerCase();
    final filtered =
        entries.where((entry) {
          final matchesType =
              _selectedType == null || entry.document.type == _selectedType;
          final matchesQuery =
              query.isEmpty ||
              entry.appliance.name.toLowerCase().contains(query) ||
              entry.document.displayTitle.toLowerCase().contains(query) ||
              entry.document.fileName.toLowerCase().contains(query) ||
              entry.document.reference.toLowerCase().contains(query);
          return matchesType && matchesQuery;
        }).toList()..sort(
          (a, b) => b.document.attachedAt.compareTo(a.document.attachedAt),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
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
                      hintText: 'Search documents',
                      leading: const Icon(Icons.search),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _selectedType == null,
                          onSelected: (_) =>
                              setState(() => _selectedType = null),
                        ),
                        const SizedBox(width: 8),
                        ...DocumentType.values
                            .where(
                              (type) => type != DocumentType.appliancePhoto,
                            )
                            .map(
                              (type) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(type.label),
                                  selected: _selectedType == type,
                                  onSelected: (_) =>
                                      setState(() => _selectedType = type),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const EmptyState(
                            icon: Icons.search_off,
                            title: 'No matching documents',
                            message: 'Try another search or document type.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final entry = filtered[index];
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: StoredDocumentTile(
                                    document: entry.document,
                                    title: entry.document.displayTitle,
                                    subtitle:
                                        '${entry.document.type.label} • ${entry.appliance.name}',
                                    onOpen: () => _openDocument(
                                      context,
                                      entry.appliance.id,
                                      entry.document,
                                    ),
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

class _DocumentEntry {
  const _DocumentEntry({required this.appliance, required this.document});

  final Appliance appliance;
  final StoredDocument document;
}
