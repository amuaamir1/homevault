import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import '../../models/appliance.dart';
import '../../models/appliance_form_result.dart';
import '../../models/document_form_result.dart';
import '../../models/service_form_result.dart';
import '../../models/service_record.dart';
import '../../models/stored_document.dart';
import '../../services/appliance_repository.dart';
import '../../services/cloud_document_storage_service.dart';
import '../../services/document_storage_service.dart';
import '../../services/support_action_service.dart';
import '../../state/app_scope.dart';
import '../../widgets/service_record_tile.dart';
import '../../widgets/stored_document_tile.dart';
import '../../widgets/warranty_status_chip.dart';
import '../documents/add_document_screen.dart';
import '../service/add_service_record_screen.dart';
import 'add_appliance_screen.dart';

class ApplianceDetailsScreen extends StatelessWidget {
  const ApplianceDetailsScreen({super.key, required this.applianceId});

  final String applianceId;

  String _date(DateTime? value) {
    if (value == null) return 'Not provided';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _remainingWarrantyText(Appliance appliance) {
    final days = appliance.warrantyDaysRemainingAt(DateTime.now());
    if (days == null) return 'Not provided';
    if (days < 0) {
      final elapsed = days.abs();
      return 'Expired $elapsed day${elapsed == 1 ? '' : 's'} ago';
    }
    if (days == 0) return 'Expires today';
    return '$days day${days == 1 ? '' : 's'} remaining';
  }

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  Future<void> _runSupportAction(
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

  Future<void> _openDocument(
    BuildContext context,
    StoredDocument document,
  ) async {
    var availableDocument = document;

    if (!availableDocument.isAvailableOnDevice) {
      if (!availableDocument.isAvailableInCloud) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This document file is unavailable. Edit the appliance and choose the file again.',
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
      } on CloudDocumentStorageException catch (error) {
        messenger.hideCurrentSnackBar();
        if (!context.mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
        return;
      } catch (_) {
        messenger.hideCurrentSnackBar();
        if (!context.mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('The document could not be prepared right now.'),
          ),
        );
        return;
      }

      messenger.hideCurrentSnackBar();
    }

    try {
      await OpenFilex.open(availableDocument.localPath);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The document could not be opened on this device.'),
        ),
      );
    }
  }

  Future<void> _edit(BuildContext context, Appliance appliance) async {
    final result = await Navigator.of(context).push<ApplianceFormResult>(
      MaterialPageRoute(
        builder: (context) => AddApplianceScreen(appliance: appliance),
      ),
    );

    if (result == null || !context.mounted) {
      return;
    }

    try {
      await AppScope.read(context).update(result.appliance);

      for (final document in result.documentsToDelete) {
        try {
          await DocumentStorageService().deleteStoredDocument(document);
        } catch (_) {
          // The record is already correct; a stale file can be cleaned later.
        }
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.appliance.name} was updated.')),
      );
    } on ApplianceConflictException catch (error) {
      for (final document in result.documentsAdded) {
        try {
          await DocumentStorageService().deleteStoredDocument(document);
        } catch (_) {
          // Keep the conflict as the important result.
        }
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      for (final document in result.documentsAdded) {
        try {
          await DocumentStorageService().deleteStoredDocument(document);
        } catch (_) {
          // Preserve the original error message if cleanup also fails.
        }
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The changes could not be saved. Please check the device storage and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _addDocument(BuildContext context, Appliance appliance) async {
    final store = AppScope.read(context);
    final result = await Navigator.of(context).push<DocumentFormResult>(
      MaterialPageRoute(
        builder: (context) => AddDocumentScreen(
          appliances: store.appliances.toList(growable: false),
          initialApplianceId: appliance.id,
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
    } catch (_) {
      try {
        await DocumentStorageService().deleteStoredDocument(result.document);
      } catch (_) {
        // Preserve the original save error if cleanup also fails.
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The document could not be saved.')),
      );
    }
  }

  Future<void> _addServiceRecord(
    BuildContext context,
    Appliance appliance,
  ) async {
    final store = AppScope.read(context);
    final result = await Navigator.of(context).push<ServiceFormResult>(
      MaterialPageRoute(
        builder: (context) => AddServiceRecordScreen(
          appliances: store.appliances.toList(growable: false),
          initialApplianceId: appliance.id,
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    await _saveServiceResult(context, result);
  }

  Future<void> _editServiceRecord(
    BuildContext context,
    Appliance appliance,
    ServiceRecord record,
  ) async {
    final store = AppScope.read(context);
    final result = await Navigator.of(context).push<ServiceFormResult>(
      MaterialPageRoute(
        builder: (context) => AddServiceRecordScreen(
          appliances: store.appliances.toList(growable: false),
          initialApplianceId: appliance.id,
          record: record,
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    await _saveServiceResult(context, result);
  }

  Future<void> _saveServiceResult(
    BuildContext context,
    ServiceFormResult result,
  ) async {
    try {
      final store = AppScope.read(context);
      if (result.isEditing) {
        await store.updateServiceRecord(result.applianceId, result.record);
      } else {
        await store.addServiceRecord(result.applianceId, result.record);
      }

      for (final document in result.documentsToDelete) {
        try {
          await DocumentStorageService().deleteStoredDocument(document);
        } catch (_) {
          // The record is saved even if a stale attachment remains.
        }
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isEditing
                ? 'Service record updated.'
                : 'Service record saved.',
          ),
        ),
      );
    } catch (_) {
      for (final document in result.documentsAdded) {
        try {
          await DocumentStorageService().deleteStoredDocument(document);
        } catch (_) {
          // Keep the original save failure as the important error.
        }
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The service record could not be saved.')),
      );
    }
  }

  Future<void> _deleteServiceRecord(
    BuildContext context,
    Appliance appliance,
    ServiceRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete service record?'),
        content: const Text(
          'The service details and attached receipt/report will be removed.',
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
      await AppScope.read(context).removeServiceRecord(appliance.id, record.id);
      for (final document in record.documents) {
        try {
          await DocumentStorageService().deleteStoredDocument(document);
        } catch (_) {
          // The record is removed even if a stale file remains.
        }
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Service record deleted.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The service record could not be deleted.'),
        ),
      );
    }
  }

  Future<void> _delete(BuildContext context, Appliance appliance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete appliance?'),
        content: Text(
          'This will remove ${appliance.name} and all attached documents.',
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
      await AppScope.read(context).delete(appliance.id);
    } on ApplianceConflictException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The appliance could not be deleted. Please try again.',
          ),
        ),
      );
      return;
    }

    try {
      await DocumentStorageService().deleteApplianceDocuments(appliance.id);
    } catch (_) {
      // The saved record was deleted successfully even if a stale file remains.
    }

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text('${appliance.name} was deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appliance = AppScope.of(context).applianceById(applianceId);

    if (appliance == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Appliance details')),
        body: const Center(
          child: Text('This appliance is no longer available.'),
        ),
      );
    }

    final supportRows = <_DetailRowData>[
      if (appliance.supportPhone.trim().isNotEmpty)
        _DetailRowData('Phone', appliance.supportPhone, Icons.phone_outlined),
      if (appliance.supportEmail.trim().isNotEmpty)
        _DetailRowData('Email', appliance.supportEmail, Icons.email_outlined),
      if (appliance.supportWebsite.trim().isNotEmpty)
        _DetailRowData('Website', appliance.supportWebsite, Icons.language),
    ];
    const supportActions = SupportActionService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appliance details'),
        actions: [
          IconButton(
            tooltip: 'Add service record',
            onPressed: () => _addServiceRecord(context, appliance),
            icon: const Icon(Icons.build_circle_outlined),
          ),
          IconButton(
            tooltip: 'Add document',
            onPressed: () => _addDocument(context, appliance),
            icon: const Icon(Icons.note_add_outlined),
          ),
          IconButton(
            tooltip: 'Edit appliance',
            onPressed: () => _edit(context, appliance),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete appliance',
            onPressed: () => _delete(context, appliance),
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
                          style: Theme.of(context).textTheme.headlineSmall
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
                label: 'Purchase / invoice date',
                value: _date(appliance.purchaseDate),
              ),
              if (appliance.warrantyDurationLabel.isNotEmpty)
                _DetailRow(
                  label: 'Warranty duration',
                  value: appliance.warrantyDurationLabel,
                ),
              _DetailRow(
                label: 'Standard warranty',
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
            title: 'Warranty management',
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
              if (appliance.warrantyDurationLabel.isNotEmpty)
                _DetailRow(
                  label: 'Original duration',
                  value: appliance.warrantyDurationLabel,
                ),
              _DetailRow(
                label: 'Effective expiry',
                value: _date(appliance.effectiveWarrantyExpiryDate),
              ),
              _DetailRow(
                label: 'Time remaining',
                value: _remainingWarrantyText(appliance),
              ),
              if (appliance.warrantyTerms.trim().isNotEmpty)
                _DetailRow(label: 'Terms', value: appliance.warrantyTerms),
              if (appliance.warrantyCoverageNotes.trim().isNotEmpty)
                _DetailRow(
                  label: 'Coverage',
                  value: appliance.warrantyCoverageNotes,
                ),
              if (appliance.hasExtendedWarranty) ...[
                const Divider(height: 24),
                Text(
                  'Extended warranty',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _DetailRow(
                  label: 'Provider',
                  value: appliance.extendedWarrantyProvider,
                ),
                _DetailRow(
                  label: 'Reference',
                  value: appliance.extendedWarrantyReference,
                ),
                _DetailRow(
                  label: 'Expiry',
                  value: _date(appliance.extendedWarrantyExpiryDate),
                ),
              ],
              if (appliance.warrantyClaimStatus != WarrantyClaimStatus.none ||
                  appliance.warrantyClaimNumber.trim().isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  'Warranty claim',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _DetailRow(
                  label: 'Claim number',
                  value: appliance.warrantyClaimNumber,
                ),
                _DetailRow(
                  label: 'Claim status',
                  value: appliance.warrantyClaimStatus.label,
                ),
              ],
              if (appliance.warrantyMarkedExpired) ...[
                const Divider(height: 24),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.gpp_bad_outlined),
                  title: Text('Marked as out of warranty'),
                  subtitle: Text(
                    'This warranty was manually marked as ended or voided.',
                  ),
                ),
              ],
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  appliance.warrantyReminderEnabled
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                ),
                title: Text(
                  appliance.warrantyReminderEnabled
                      ? 'Reminder enabled'
                      : 'Reminder disabled',
                ),
                subtitle: Text(
                  appliance.warrantyReminderEnabled
                      ? '${appliance.warrantyReminderDaysBefore} days before the effective expiry date'
                      : 'Edit the appliance to enable a reminder.',
                ),
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
            title: 'Service and maintenance',
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${appliance.serviceRecordCount} record${appliance.serviceRecordCount == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total cost: ${_formatIndianCurrency(appliance.totalServiceCost)}/-',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _addServiceRecord(context, appliance),
                    icon: const Icon(Icons.add),
                    label: const Text('Add service'),
                  ),
                ],
              ),
              if (appliance.lastServiceDate != null)
                _DetailRow(
                  label: 'Last serviced',
                  value: _date(appliance.lastServiceDate),
                ),
              if (appliance.serviceFrequencyLabel.isNotEmpty)
                _DetailRow(
                  label: 'Service frequency',
                  value: appliance.serviceFrequencyLabel,
                ),
              if (appliance.nextServiceDate != null)
                _DetailRow(
                  label: 'Next service',
                  value: _date(appliance.nextServiceDate),
                ),
              if (appliance.serviceRecords.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No service or maintenance records added.'),
                )
              else
                ...([
                  ...appliance.serviceRecords,
                ]..sort((a, b) => b.serviceDate.compareTo(a.serviceDate))).map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ServiceRecordTile(
                      record: record,
                      onEdit: () =>
                          _editServiceRecord(context, appliance, record),
                      onDelete: () =>
                          _deleteServiceRecord(context, appliance, record),
                    ),
                  ),
                ),
            ],
          ),
          if (appliance.additionalDocuments.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DetailsSection(
              title: 'Additional documents',
              children: appliance.additionalDocuments
                  .map(
                    (document) => StoredDocumentTile(
                      document: document,
                      title: document.displayTitle,
                      subtitle: document.type.label,
                      onOpen: () => _openDocument(context, document),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          _DetailsSection(
            title: 'Customer support',
            children: !appliance.hasSupportDetails
                ? const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No support contact details added.'),
                    ),
                  ]
                : [
                    if (appliance.supportProvider.trim().isNotEmpty)
                      _DetailRow(
                        label: 'Provider',
                        value: appliance.supportProvider,
                      ),
                    if (appliance.hasSupportAction) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (appliance.supportPhone.trim().isNotEmpty)
                            FilledButton.tonalIcon(
                              onPressed: () => _runSupportAction(
                                context,
                                () =>
                                    supportActions.call(appliance.supportPhone),
                              ),
                              icon: const Icon(Icons.phone_outlined),
                              label: const Text('Call'),
                            ),
                          if (appliance.supportEmail.trim().isNotEmpty)
                            FilledButton.tonalIcon(
                              onPressed: () => _runSupportAction(
                                context,
                                () => supportActions.email(appliance),
                              ),
                              icon: const Icon(Icons.email_outlined),
                              label: const Text('Email'),
                            ),
                          if (appliance.supportWebsite.trim().isNotEmpty)
                            FilledButton.tonalIcon(
                              onPressed: () => _runSupportAction(
                                context,
                                () => supportActions.openWebsite(
                                  appliance.supportWebsite,
                                ),
                              ),
                              icon: const Icon(Icons.language),
                              label: const Text('Website'),
                            ),
                        ],
                      ),
                      const Divider(height: 24),
                    ],
                    ...supportRows.map(
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
                    ),
                    if (appliance.supportNotes.trim().isNotEmpty) ...[
                      const Divider(height: 24),
                      _DetailRow(
                        label: 'Support notes',
                        value: appliance.supportNotes,
                      ),
                    ],
                  ],
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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

String _formatIndianCurrency(double value) {
  if (!value.isFinite) return '₹0';

  final rounded = value.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  if (digits.length <= 3) {
    return '${negative ? '-' : ''}₹$digits';
  }

  final lastThree = digits.substring(digits.length - 3);
  var leading = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (leading.length > 2) {
    groups.insert(0, leading.substring(leading.length - 2));
    leading = leading.substring(0, leading.length - 2);
  }
  if (leading.isNotEmpty) groups.insert(0, leading);

  return '${negative ? '-' : ''}₹${groups.join(',')},$lastThree';
}

class _DetailRowData {
  const _DetailRowData(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}
