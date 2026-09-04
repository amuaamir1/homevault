import 'dart:async';

import 'package:flutter/material.dart';

import '../../accessibility/homevault_accessibility.dart';
import '../../auth/auth_scope.dart';
import '../../models/appliance.dart';
import '../../models/backup_models.dart';
import '../../services/crash_reporting_service.dart';
import '../../services/homevault_backup_service.dart';
import '../../services/homevault_error_message.dart';
import '../../services/homevault_export_service.dart';
import '../../state/app_scope.dart';
import '../auth/sensitive_action_verification_dialog.dart';
import 'appliance_support_pack_screen.dart';
import 'cloud_backup_screen.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final _backupService = HomeVaultBackupService();
  final _exportService = const HomeVaultExportService();
  String? _busyMessage;

  bool get _isBusy => _busyMessage != null;

  Future<void> _createBackup() async {
    final store = AppScope.read(context);
    if (store.appliances.isEmpty) {
      _showMessage('There is no HomeVault data to back up yet.');
      return;
    }

    await _runBusy('Creating your backup...', () async {
      final result = await _backupService.createAndSaveBackup(
        store.appliances,
        ownerUid: AuthScope.read(context).user?.uid,
      );
      if (!mounted || result == null) return;

      final omitted = result.missingDocuments == 0
          ? ''
          : ' ${result.missingDocuments} missing document file(s) were omitted.';
      _showMessage(
        'Backup saved with ${result.applianceCount} appliance(s) and '
        '${result.documentCount} document(s).$omitted',
      );
    });
  }

  Future<void> _restoreBackup() async {
    BackupSelection? selection;
    try {
      selection = await _backupService.pickBackup();
    } catch (error) {
      if (!mounted) return;
      _showError(error);
      return;
    }
    if (!mounted || selection == null) return;

    final mode = await _selectRestoreMode(selection.preview);
    if (!mounted || mode == null) return;

    if (mode == RestoreMode.replace) {
      final confirmed = await _confirmReplacement();
      if (!mounted || !confirmed) return;

      final verified = await verifySensitiveAction(
        context,
        title: 'Verify before replacing data',
        message:
            'Replacing current HomeVault data can remove records that are not '
            'present in the selected backup.',
      );
      if (!mounted || !verified) return;
    }

    await _runBusy('Restoring HomeVault data...', () async {
      final store = AppScope.read(context);
      final uid = AuthScope.read(context).user?.uid;
      final prepared = await _backupService.prepareRestore(
        selection: selection!,
        existingAppliances: store.appliances,
        mode: mode,
        currentOwnerUid: uid,
      );

      String? safetyBackupPath;
      try {
        if (mode == RestoreMode.replace) {
          if (uid != null) {
            safetyBackupPath = await _backupService.createSafetyBackup(
              store.appliances,
              ownerUid: uid,
            );
          }
          await store.replaceAll(prepared.appliances);
        } else {
          await store.mergeAppliances(prepared.appliances);
        }
      } catch (_) {
        await _backupService.cleanupCreatedFiles(prepared.createdFilePaths);
        rethrow;
      }

      // The actual restore is complete once the appliance data has been
      // persisted. Orphan-file cleanup is best-effort housekeeping and should
      // never hold the user on a blocking restore spinner.
      unawaited(
        _cleanupAfterRestore(
          store.appliances,
          ownerUid: uid,
          protectedFilePaths: prepared.createdFilePaths,
        ),
      );

      if (!mounted) return;
      // Remove the blocking overlay before presenting the completion dialog.
      setState(() => _busyMessage = null);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore completed'),
          content: Text(
            '${prepared.importedAppliances} appliance(s) imported.\n'
            '${prepared.restoredDocuments} document(s) restored.\n'
            '${prepared.skippedDuplicates} duplicate appliance(s) skipped.\n'
            '${prepared.missingDocuments} missing document file(s).'
            '${safetyBackupPath == null ? '' : '\nA safety backup of the replaced data was created automatically.'}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _cleanupAfterRestore(
    Iterable<Appliance> appliances, {
    String? ownerUid,
    Iterable<String> protectedFilePaths = const [],
  }) async {
    try {
      await _backupService
          .cleanupUnreferencedDocuments(
            appliances,
            ownerUid: ownerUid,
            protectedFilePaths: protectedFilePaths,
          )
          .timeout(const Duration(seconds: 10));
    } catch (error, stack) {
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Cleaning up local files after a HomeVault restore',
      );
    }
  }

  Future<RestoreMode?> _selectRestoreMode(BackupPreview preview) {
    return showDialog<RestoreMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore HomeVault backup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: 'Selected HomeVault backup',
                excludeSemantics: true,
                child: Text(
                  preview.fileName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 10),
              _PreviewRow(
                label: 'Created',
                value: _dateTime(preview.createdAt),
              ),
              _PreviewRow(label: 'App version', value: preview.appVersion),
              _PreviewRow(
                label: 'Appliances',
                value: '${preview.applianceCount}',
              ),
              _PreviewRow(
                label: 'Documents',
                value: '${preview.documentCount}',
              ),
              _PreviewRow(
                label: 'Ownership',
                value: preview.ownerFingerprint == null
                    ? 'Legacy backup'
                    : 'Account protected',
              ),
              if (preview.missingDocumentCount > 0)
                _PreviewRow(
                  label: 'Missing files',
                  value: '${preview.missingDocumentCount}',
                ),
              const SizedBox(height: 16),
              const Text('Choose how the backup should be restored:'),
              const SizedBox(height: 10),
              ...RestoreMode.values.map(
                (mode) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(mode.label),
                    subtitle: Text(mode.description),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pop(mode),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmReplacement() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.warning_amber_outlined),
            title: const Text('Replace current HomeVault data?'),
            content: const Text(
              'The current appliance database will be replaced by the backup. '
              'Create a fresh backup first if the current records are important.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Replace data'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _exportInventory() async {
    final store = AppScope.read(context);
    await _runExport(
      message: 'Creating appliance inventory...',
      successMessage: 'Appliance inventory saved.',
      action: () => _exportService.exportApplianceInventory(store.appliances),
    );
  }

  Future<void> _exportWarrantyReport() async {
    final store = AppScope.read(context);
    await _runExport(
      message: 'Creating warranty report...',
      successMessage: 'Warranty report saved.',
      action: () => _exportService.exportWarrantyReport(store.appliances),
    );
  }

  Future<void> _exportServiceReport() async {
    final store = AppScope.read(context);
    await _runExport(
      message: 'Creating service cost report...',
      successMessage: 'Service cost report saved.',
      action: () => _exportService.exportServiceCostReport(store.appliances),
    );
  }

  Future<Appliance?> _chooseApplianceForPdf() async {
    final appliances = AppScope.read(context).appliances;
    if (appliances.isEmpty) {
      _showMessage('Add an appliance before creating a PDF summary.');
      return null;
    }

    return showModalBottomSheet<Appliance>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Choose an appliance',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: appliances.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = appliances[index];
                  return ListTile(
                    leading: const Icon(Icons.home_repair_service_outlined),
                    title: Text(item.name),
                    subtitle: Text(
                      [
                        item.brand,
                        item.modelNumber,
                      ].where((value) => value.trim().isNotEmpty).join(' - '),
                    ),
                    onTap: () => Navigator.of(context).pop(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAppliancePdf() async {
    final appliance = await _chooseApplianceForPdf();
    if (!mounted || appliance == null) return;

    await _runExport(
      message: 'Creating appliance PDF...',
      successMessage: 'Appliance PDF saved.',
      action: () => _exportService.exportAppliancePdf(appliance),
    );
  }

  Future<void> _openSupportPackBuilder() async {
    final appliance = await _chooseApplianceForPdf();
    if (!mounted || appliance == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ApplianceSupportPackScreen(applianceId: appliance.id),
      ),
    );
  }

  Future<void> _runExport({
    required String message,
    required String successMessage,
    required Future<bool> Function() action,
  }) async {
    await _runBusy(message, () async {
      final saved = await action();
      if (mounted && saved) {
        _showMessage(successMessage);
      }
    });
  }

  Future<void> _runBusy(
    String message,
    Future<void> Function() operation,
  ) async {
    if (_isBusy) return;
    setState(() => _busyMessage = message);
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _busyMessage = null);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(Object error) {
    final message = friendlyHomeVaultError(
      error,
      fallback: 'The backup operation could not be completed. Try again.',
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final documentCount = store.appliances.fold<int>(
      0,
      (total, appliance) => total + appliance.documentCount,
    );

    return PopScope(
      canPop: !_isBusy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Backup, restore & export')),
        body: Stack(
          children: [
            ExcludeSemantics(
              excluding: _isBusy,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HomeVaultSectionHeading(
                            child: Text(
                              'Protect your HomeVault data',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'A full backup includes appliance records, warranty and support details, service history, and document files.',
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _CountChip(
                                  icon: Icons.home_repair_service_outlined,
                                  label: '${store.totalCount} appliances',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _CountChip(
                                  icon: Icons.description_outlined,
                                  label: '$documentCount documents',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _CountChip(
                                  icon: Icons.build_outlined,
                                  label:
                                      '${store.totalServiceRecordCount} services',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.cloud_outlined),
                      title: const Text('Cloud backup & recovery'),
                      subtitle: const Text(
                        'Automatic restore points, Backup now, history, and recovery.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: !_isBusy,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => const CloudBackupScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.backup_outlined),
                          title: const Text('Create full backup'),
                          subtitle: const Text(
                            'Save all records and available document files as a ZIP backup.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          enabled: !_isBusy,
                          onTap: _createBackup,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.restore_outlined),
                          title: const Text('Restore from backup'),
                          subtitle: const Text(
                            'Validate a backup, then merge it or replace current data.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          enabled: !_isBusy,
                          onTap: _restoreBackup,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        const ListTile(
                          leading: Icon(Icons.table_view_outlined),
                          title: Text('CSV reports'),
                          subtitle: Text('Save CSV reports to Files.'),
                        ),
                        const Divider(height: 1),
                        _ExportTile(
                          title: 'Appliance inventory',
                          saveKey: 'p17SaveInventoryButton',
                          enabled: !_isBusy && store.appliances.isNotEmpty,
                          onSave: _exportInventory,
                        ),
                        const Divider(height: 1),
                        _ExportTile(
                          title: 'Warranty report',
                          saveKey: 'p17SaveWarrantyButton',
                          enabled: !_isBusy && store.appliances.isNotEmpty,
                          onSave: _exportWarrantyReport,
                        ),
                        const Divider(height: 1),
                        _ExportTile(
                          title: 'Service cost report',
                          saveKey: 'p17SaveServiceCostButton',
                          enabled: !_isBusy && store.appliances.isNotEmpty,
                          onSave: _exportServiceReport,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.picture_as_pdf_outlined),
                      title: const Text('Appliance summary PDF'),
                      subtitle: const Text(
                        'Choose one appliance, then save its printable summary.',
                      ),
                      trailing: IconButton(
                        key: const ValueKey('p17SaveAppliancePdfButton'),
                        tooltip: 'Save appliance summary PDF',
                        onPressed: _isBusy || store.appliances.isEmpty
                            ? null
                            : _exportAppliancePdf,
                        icon: const Icon(Icons.download_outlined),
                      ),
                      enabled: !_isBusy && store.appliances.isNotEmpty,
                      onTap: _exportAppliancePdf,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      key: const ValueKey('p17SupportPackTile'),
                      leading: const Icon(Icons.folder_zip_outlined),
                      title: const Text('Appliance support pack'),
                      subtitle: const Text(
                        'Choose an appliance, then select the documents and optional service history to save in one support ZIP.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: !_isBusy && store.appliances.isNotEmpty,
                      onTap: _isBusy || store.appliances.isEmpty
                          ? null
                          : _openSupportPackBuilder,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.lock_open_outlined),
                      title: Text('Saved file security'),
                      subtitle: Text(
                        'Backups, reports, document copies, and support packs are not encrypted after you save them. Store them in a private, trusted location.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isBusy)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black26,
                  child: Center(
                    child: Semantics(
                      container: true,
                      liveRegion: true,
                      label: _busyMessage!,
                      child: ExcludeSemantics(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(_busyMessage!),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _dateTime(DateTime value) {
    final date =
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({
    required this.title,
    required this.saveKey,
    required this.enabled,
    required this.onSave,
  });

  final String title;
  final String saveKey;
  final bool enabled;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      enabled: enabled,
      onTap: enabled ? onSave : null,
      trailing: IconButton(
        key: ValueKey(saveKey),
        tooltip: HomeVaultAccessibility.contextualAction('Save', title),
        onPressed: enabled ? onSave : null,
        icon: const Icon(Icons.download_outlined),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 5),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                label,
                maxLines: 1,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
