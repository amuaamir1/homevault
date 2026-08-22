import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../models/appliance.dart';
import '../../models/backup_models.dart';
import '../../services/cloud_backup_service.dart';
import '../../services/crash_reporting_service.dart';
import '../../services/homevault_backup_service.dart';
import '../../state/app_scope.dart';

class CloudBackupScreen extends StatefulWidget {
  const CloudBackupScreen({super.key});

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  final _cloudService = CloudBackupService();
  final _backupService = HomeVaultBackupService();

  List<CloudBackupSnapshot> _backups = const [];
  String? _busyMessage;
  String? _historyError;
  String? _loadedUid;
  bool _loadingHistory = false;

  bool get _isBusy => _busyMessage != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = AuthScope.of(context).user?.uid;
    if (uid != null && uid.isNotEmpty && _loadedUid != uid) {
      _loadedUid = uid;
      unawaited(_loadHistory());
    }
  }

  Future<void> _loadHistory() async {
    final uid = AuthScope.read(context).user?.uid ?? '';
    if (uid.isEmpty || _loadingHistory) return;

    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });

    try {
      final backups = await _cloudService.listBackups(uid);
      if (!mounted || AuthScope.read(context).user?.uid != uid) return;
      setState(() => _backups = backups);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _historyError = error is CloudBackupException
            ? error.message
            : 'Cloud backup history could not be loaded.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  Future<void> _backupNow() async {
    final store = AppScope.read(context);
    final uid = AuthScope.read(context).user?.uid ?? '';
    if (store.appliances.isEmpty) {
      _showMessage('There is no HomeVault data to back up yet.');
      return;
    }

    await _runBusy('Creating cloud backup...', () async {
      await store.ensureCloudDocumentSyncComplete().timeout(
        const Duration(minutes: 2),
      );
      final snapshot = await _cloudService.createBackup(
        uid: uid,
        appliances: store.appliances,
        source: CloudBackupSource.manual,
      );
      if (!mounted) return;
      await _loadHistory();
      if (!mounted) return;
      _showMessage(
        'Cloud backup created with ${snapshot.applianceCount} appliance(s) '
        'and ${snapshot.documentCount} attachment(s).',
      );
    });
  }

  Future<void> _restoreSnapshot(CloudBackupSnapshot snapshot) async {
    BackupSelection? selection;

    await _runBusy('Downloading cloud backup...', () async {
      final uid = AuthScope.read(context).user?.uid ?? '';
      selection = await _cloudService.downloadBackup(
        uid: uid,
        snapshot: snapshot,
      );
    });

    if (!mounted || selection == null) return;

    final mode = await _selectRestoreMode(selection!.preview);
    if (!mounted || mode == null) return;

    if (mode == RestoreMode.replace) {
      final confirmed = await _confirmReplacement();
      if (!mounted || !confirmed) return;
    }

    await _runBusy('Restoring cloud backup...', () async {
      final uid = AuthScope.read(context).user?.uid ?? '';
      final store = AppScope.read(context);

      if (mode == RestoreMode.replace && store.appliances.isNotEmpty) {
        // A destructive restore is not allowed to proceed unless the current
        // state can first be captured completely in cloud storage.
        await store.ensureCloudDocumentSyncComplete().timeout(
          const Duration(minutes: 2),
        );
        await _cloudService.createBackup(
          uid: uid,
          appliances: store.appliances,
          source: CloudBackupSource.preRestoreSafety,
        );
        await _backupService.createSafetyBackup(
          store.appliances,
          ownerUid: uid,
        );
      }

      _updateBusyMessage('Preparing restored files...');
      final prepared = await _backupService.prepareRestore(
        selection: selection!,
        existingAppliances: store.appliances,
        mode: mode,
        currentOwnerUid: uid,
      );

      _updateBusyMessage(
        mode == RestoreMode.replace
            ? 'Replacing appliance data...'
            : 'Merging appliance data...',
      );

      try {
        if (mode == RestoreMode.replace) {
          await store.replaceAll(prepared.appliances);
        } else {
          await store.mergeAppliances(prepared.appliances);
        }
      } catch (_) {
        await _backupService.cleanupCreatedFiles(prepared.createdFilePaths);
        rethrow;
      }

      unawaited(
        _cleanupAfterRestore(
          store.appliances,
          ownerUid: uid,
          protectedFilePaths: prepared.createdFilePaths,
        ),
      );
      unawaited(store.retryCloudDocumentSync());

      _updateBusyMessage('Finishing restore...');
      if (!mounted) return;
      setState(() => _busyMessage = null);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cloud restore completed'),
          content: Text(
            '${prepared.importedAppliances} appliance(s) imported.\n'
            '${prepared.restoredDocuments} attachment(s) restored.\n'
            '${prepared.skippedDuplicates} duplicate appliance(s) skipped.\n'
            '${prepared.missingDocuments} missing attachment file(s).'
            '${mode == RestoreMode.replace ? '\nA safety snapshot was created before replacement.' : ''}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      await _loadHistory();
    });
  }

  Future<void> _deleteSnapshot(CloudBackupSnapshot snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete cloud backup?'),
        content: Text(
          'Delete the ${snapshot.source.label.toLowerCase()} backup from '
          '${_dateTime(snapshot.createdAt.toLocal())}? This cannot be undone.',
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

    if (!mounted || confirmed != true) return;

    await _runBusy('Deleting cloud backup...', () async {
      final uid = AuthScope.read(context).user?.uid ?? '';
      await _cloudService.deleteBackup(uid: uid, snapshot: snapshot);
      if (!mounted) return;
      await _loadHistory();
      if (mounted) _showMessage('Cloud backup deleted.');
    });
  }

  Future<void> _cleanupAfterRestore(
    Iterable<Appliance> appliances, {
    required String ownerUid,
    required Iterable<String> protectedFilePaths,
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
        reason: 'Cleaning up local files after a cloud restore',
      );
    }
  }

  Future<RestoreMode?> _selectRestoreMode(BackupPreview preview) {
    return showDialog<RestoreMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore cloud backup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                label: 'Attachments',
                value: '${preview.documentCount}',
              ),
              const SizedBox(height: 14),
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
              'HomeVault will first create a safety cloud snapshot and local '
              'safety backup, then replace the current appliance data.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Create safety backup & replace'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _updateBusyMessage(String message) {
    if (!mounted || _busyMessage == null || _busyMessage == message) {
      return;
    }
    setState(() => _busyMessage = message);
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
      if (mounted) _showError(error);
    } finally {
      if (mounted && _busyMessage != null) {
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
    final String message;
    if (error is CloudBackupException) {
      message = error.message;
    } else if (error is BackupFormatException) {
      message = error.message;
    } else {
      message = 'The operation could not be completed. Please try again.';
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final lastSuccessful = _backups.isEmpty ? null : _backups.first;

    return PopScope(
      canPop: !_isBusy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cloud backup & recovery'),
          actions: [
            IconButton(
              tooltip: 'Refresh backup history',
              onPressed: _isBusy || _loadingHistory ? null : _loadHistory,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cloud_done_outlined),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Protected cloud snapshots',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lastSuccessful == null
                                ? 'No cloud backup has been created yet.'
                                : 'Last successful backup: '
                                      '${_dateTime(lastSuccessful.createdAt.toLocal())}',
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'HomeVault automatically backs up after saved data '
                            'changes and also checks once per day as a fallback. '
                            'Only the latest 2 cloud restore points are kept.',
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _isBusy ? null : _backupNow,
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Backup now'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_historyError != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.cloud_off_outlined),
                        title: const Text('Backup history unavailable'),
                        subtitle: Text(_historyError!),
                        trailing: TextButton(
                          onPressed: _loadHistory,
                          child: const Text('Retry'),
                        ),
                      ),
                    )
                  else if (_loadingHistory && _backups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_backups.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.history_outlined),
                        title: Text('No cloud backup history'),
                        subtitle: Text(
                          'Use Backup now to create your first restore point.',
                        ),
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                      child: Text(
                        'Backup history',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    ..._backups.map(
                      (backup) => _CloudBackupTile(
                        backup: backup,
                        dateTimeText: _dateTime(backup.createdAt.toLocal()),
                        sizeText: _fileSize(backup.sizeBytes),
                        enabled: !_isBusy,
                        onRestore: () => _restoreSnapshot(backup),
                        onDelete: () => _deleteSnapshot(backup),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.security_outlined),
                      title: Text('Account-isolated storage'),
                      subtitle: Text(
                        'Cloud backups are stored under your Firebase user ID '
                        'and can only be accessed by that signed-in account. '
                        'They are not end-to-end encrypted.',
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
          ],
        ),
      ),
    );
  }

  String _dateTime(DateTime value) {
    final date =
        '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year.toString().padLeft(4, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  String _fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}

class _CloudBackupTile extends StatelessWidget {
  const _CloudBackupTile({
    required this.backup,
    required this.dateTimeText,
    required this.sizeText,
    required this.enabled,
    required this.onRestore,
    required this.onDelete,
  });

  final CloudBackupSnapshot backup;
  final String dateTimeText;
  final String sizeText;
  final bool enabled;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(switch (backup.source) {
            CloudBackupSource.automatic => Icons.schedule_outlined,
            CloudBackupSource.manual => Icons.person_outline,
            CloudBackupSource.preRestoreSafety =>
              Icons.health_and_safety_outlined,
          }),
        ),
        title: Text(
          '${backup.source.label} • $dateTimeText',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${backup.applianceCount} appliances • '
          '${backup.documentCount} attachments • $sizeText',
        ),
        trailing: PopupMenuButton<_BackupAction>(
          enabled: enabled,
          onSelected: (action) {
            if (action == _BackupAction.restore) {
              onRestore();
            } else {
              onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _BackupAction.restore,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.restore_outlined),
                title: Text('Restore'),
              ),
            ),
            PopupMenuItem(
              value: _BackupAction.delete,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline),
                title: Text('Delete'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _BackupAction { restore, delete }

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
