import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import '../../models/appliance.dart';
import '../../models/stored_document.dart';
import '../../services/document_storage_service.dart';
import '../../state/app_scope.dart';
import '../../widgets/stored_document_tile.dart';
import '../../widgets/warranty_status_chip.dart';

class ApplianceDetailsScreen extends StatelessWidget {
  const ApplianceDetailsScreen({
    super.key,
    required this.appliance,
  });

  final Appliance appliance;

  String _date(DateTime? value) {
    if (value == null) return 'Not provided';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied.')),
    );
  }

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

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete appliance?'),
        content: Text(
          'This will remove ${appliance.name} and its attached invoice and warranty files.',
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
      await DocumentStorageService().deleteApplianceDocuments(appliance.id);
    } catch (_) {
      // The appliance record should still be removable if a stale file path exists.
    }

    if (!context.mounted) return;
    AppScope.read(context).delete(appliance.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final supportRows = <_DetailRowData>[
      if (appliance.supportPhone.isNotEmpty)
        _DetailRowData('Phone', appliance.supportPhone, Icons.phone_outlined),
      if (appliance.supportEmail.isNotEmpty)
        _DetailRowData('Email', appliance.supportEmail, Icons.email_outlined),
      if (appliance.supportWebsite.isNotEmpty)
        _DetailRowData('Website', appliance.supportWebsite, Icons.language),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appliance details'),
        actions: [
          IconButton(
            tooltip: 'Delete appliance',
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    child: Icon(Icons.devices_other, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appliance.name,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(appliance.category),
                        const SizedBox(height: 10),
                        WarrantyStatusChip(
                          status: appliance.warrantyStatusAt(DateTime.now()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DetailsSection(
            title: 'Product information',
            children: [
              _DetailRow(label: 'Brand', value: appliance.brand),
              _DetailRow(label: 'Model number', value: appliance.modelNumber),
              _DetailRow(label: 'Serial number', value: appliance.serialNumber),
              _DetailRow(
                label: 'Purchase date',
                value: _date(appliance.purchaseDate),
              ),
              _DetailRow(
                label: 'Warranty expiry',
                value: _date(appliance.warrantyExpiryDate),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailsSection(
            title: 'Invoice',
            children: [
              _DetailRow(
                label: 'Reference',
                value: appliance.invoiceReference,
                emptyText: 'No invoice reference added',
              ),
              if (appliance.invoiceDocument != null) ...[
                const Divider(height: 24),
                StoredDocumentTile(
                  document: appliance.invoiceDocument!,
                  title: 'Open invoice',
                  subtitle: 'Invoice attachment',
                  onOpen: () =>
                      _openDocument(context, appliance.invoiceDocument!),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text('No invoice file attached.'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailsSection(
            title: 'Warranty card',
            children: [
              _DetailRow(
                label: 'Provider',
                value: appliance.warrantyProvider,
                emptyText: 'No warranty provider added',
              ),
              _DetailRow(
                label: 'Reference',
                value: appliance.warrantyReference,
                emptyText: 'No warranty card reference added',
              ),
              if (appliance.warrantyDocument != null) ...[
                const Divider(height: 24),
                StoredDocumentTile(
                  document: appliance.warrantyDocument!,
                  title: 'Open warranty card',
                  subtitle: 'Warranty attachment',
                  onOpen: () =>
                      _openDocument(context, appliance.warrantyDocument!),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text('No warranty card file attached.'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailsSection(
            title: 'Customer support',
            children: supportRows.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No support contact details added.'),
                    ),
                  ]
                : supportRows
                    .map(
                      (row) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(row.icon),
                        title: Text(row.label),
                        subtitle: Text(row.value),
                        trailing: IconButton(
                          tooltip: 'Copy ${row.label.toLowerCase()}',
                          onPressed: () => _copy(context, row.label, row.value),
                          icon: const Icon(Icons.copy_outlined),
                        ),
                      ),
                    )
                    .toList(),
          ),
          if (appliance.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DetailsSection(
              title: 'Notes',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(appliance.notes),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.title, required this.children});

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
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emptyText = 'Not provided',
  });

  final String label;
  final String value;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? emptyText : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRowData {
  const _DetailRowData(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}
