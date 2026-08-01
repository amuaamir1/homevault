import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../models/appliance.dart';
import '../../models/stored_document.dart';
import '../../state/app_scope.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stored_document_tile.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  Future<void> _openDocument(
    BuildContext context,
    StoredDocument document,
  ) async {
    try {
      await OpenFilex.open(document.localPath);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The document could not be opened on this device.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = <_DocumentEntry>[];

    for (final appliance in AppScope.of(context).appliances) {
      final invoice = appliance.invoiceDocument;
      if (invoice != null) {
        entries.add(
          _DocumentEntry(
            appliance: appliance,
            document: invoice,
            typeLabel: 'Invoice',
          ),
        );
      }

      final warranty = appliance.warrantyDocument;
      if (warranty != null) {
        entries.add(
          _DocumentEntry(
            appliance: appliance,
            document: warranty,
            typeLabel: 'Warranty card',
          ),
        );
      }
    }

    entries.sort(
      (a, b) => b.document.attachedAt.compareTo(a.document.attachedAt),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: entries.isEmpty
          ? const EmptyState(
              icon: Icons.folder_copy_outlined,
              title: 'Your document vault is empty',
              message:
                  'Add an appliance and attach an invoice or warranty card. Supported file types are PDF, JPG, JPEG, and PNG.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Invoice and warranty files',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${entries.length} ${entries.length == 1 ? 'document' : 'documents'} stored inside the app.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                ...entries.map(
                  (entry) => Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: StoredDocumentTile(
                        document: entry.document,
                        title: entry.typeLabel,
                        subtitle: entry.appliance.name,
                        onOpen: () => _openDocument(context, entry.document),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DocumentEntry {
  const _DocumentEntry({
    required this.appliance,
    required this.document,
    required this.typeLabel,
  });

  final Appliance appliance;
  final StoredDocument document;
  final String typeLabel;
}
