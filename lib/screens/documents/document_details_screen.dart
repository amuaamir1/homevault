import 'package:flutter/material.dart';

import '../../models/appliance.dart';
import '../../models/stored_document.dart';
import '../../services/document_vault_service.dart';

enum DocumentDetailsAction { open, edit, delete }

class DocumentDetailsScreen extends StatelessWidget {
  const DocumentDetailsScreen({
    super.key,
    required this.appliance,
    required this.document,
  });

  final Appliance appliance;
  final StoredDocument document;

  String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String get _availabilityLabel {
    if (document.isAvailableOnDevice && document.isAvailableInCloud) {
      return 'Available on this device and backed up';
    }
    if (document.isAvailableOnDevice) {
      return 'Available on this device';
    }
    if (document.isAvailableInCloud) {
      return 'Available in cloud storage';
    }
    return 'File unavailable';
  }

  IconData get _availabilityIcon {
    if (document.isAvailableOnDevice) return Icons.phone_android_outlined;
    if (document.isAvailableInCloud) return Icons.cloud_outlined;
    return Icons.warning_amber_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final entry = DocumentVaultEntry(appliance: appliance, document: document);
    final canOpen = document.isAvailableOnDevice || document.isAvailableInCloud;

    return Scaffold(
      appBar: AppBar(title: const Text('Document details')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(DocumentDetailsAction.edit),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: canOpen
                    ? () =>
                          Navigator.of(context).pop(DocumentDetailsAction.open)
                    : null,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open'),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          child: Icon(_iconForDocumentType(document.type)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                document.displayTitle,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${document.type.label} • ${entry.category.label}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_availabilityIcon),
                      title: const Text('Availability'),
                      subtitle: Text(_availabilityLabel),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _DetailsCard(
              title: 'Linked appliance',
              children: [
                _DetailRow(label: 'Appliance', value: appliance.name),
                _DetailRow(label: 'Category', value: appliance.category),
                if (appliance.brand.trim().isNotEmpty)
                  _DetailRow(label: 'Brand', value: appliance.brand),
                if (appliance.modelNumber.trim().isNotEmpty)
                  _DetailRow(label: 'Model', value: appliance.modelNumber),
                if (appliance.serialNumber.trim().isNotEmpty)
                  _DetailRow(
                    label: 'Serial number',
                    value: appliance.serialNumber,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _DetailsCard(
              title: 'File information',
              children: [
                _DetailRow(label: 'File name', value: document.fileName),
                _DetailRow(label: 'Size', value: document.formattedSize),
                _DetailRow(label: 'Added', value: _date(document.attachedAt)),
                if (document.reference.trim().isNotEmpty)
                  _DetailRow(label: 'Reference', value: document.reference),
                if (document.notes.trim().isNotEmpty)
                  _DetailRow(label: 'Notes', value: document.notes),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pop(DocumentDetailsAction.delete),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete document'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

IconData _iconForDocumentType(DocumentType type) => switch (type) {
  DocumentType.appliancePhoto => Icons.photo_outlined,
  DocumentType.invoice => Icons.receipt_long_outlined,
  DocumentType.warrantyCard => Icons.verified_user_outlined,
  DocumentType.extendedWarranty => Icons.shield_outlined,
  DocumentType.amcContract => Icons.handyman_outlined,
  DocumentType.userManual => Icons.menu_book_outlined,
  DocumentType.serviceReceipt => Icons.receipt_outlined,
  DocumentType.serviceReport => Icons.build_circle_outlined,
  DocumentType.installationReport => Icons.build_outlined,
  DocumentType.other => Icons.description_outlined,
};
