import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../models/stored_document.dart';
import '../../services/homevault_error_presenter.dart';
import '../../services/local_data_management_service.dart';
import '../../state/app_scope.dart';

class DeviceStorageManagementScreen extends StatefulWidget {
  const DeviceStorageManagementScreen({super.key});

  @override
  State<DeviceStorageManagementScreen> createState() =>
      _DeviceStorageManagementScreenState();
}

class _DeviceStorageManagementScreenState
    extends State<DeviceStorageManagementScreen> {
  final LocalDataManagementService _service = LocalDataManagementService();

  LocalStorageSummary? _summary;
  bool _loading = true;
  bool _busy = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final auth = AuthScope.read(context);
      final store = AppScope.read(context);
      final uid = auth.user?.uid ?? '';
      final documents = store.appliances
          .expand((appliance) => appliance.allAttachments)
          .cast<StoredDocument>();

      final summary = await _service.summarize(
        documents: documents,
        ownerUid: uid,
      );
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearDownloadedCopies() async {
    final summary = _summary;
    if (_busy || summary == null || !summary.hasRecoverableLocalCopies) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Release downloaded document copies?'),
        content: Text(
          'HomeVault will remove ${summary.cloudBackedDocumentCount} local '
          'document copy/copies (${formatManagedBytes(summary.cloudBackedDocumentBytes)}) '
          'that are already protected in your HomeVault cloud storage.\n\n'
          'Local-only files are excluded. Cloud files and appliance records '
          'will not be deleted. Released documents can be downloaded again '
          'when you open them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Release copies'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _busy = true);
    try {
      final result = await AppScope.read(
        context,
      ).clearDownloadedDocumentCopies();
      if (!mounted) return;

      final message = result.failedItems == 0
          ? '${result.itemCount} local document copy/copies released. '
                '${formatManagedBytes(result.bytesFreed)} freed.'
          : '${result.itemCount} copy/copies released. '
                '${result.failedItems} file(s) could not be removed and can be cleaned up later.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'HomeVault could not release the local document copies.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearSafetyBackups() async {
    final summary = _summary;
    if (_busy || summary == null || !summary.hasSafetyBackups) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete local safety backups?'),
        content: Text(
          'Delete ${summary.safetyBackupCount} HomeVault-managed local safety '
          'backup(s) (${formatManagedBytes(summary.safetyBackupBytes)}) from '
          'this device?\n\nCloud backups and any ZIP backups you explicitly '
          'saved to another folder are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete safety backups'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _busy = true);
    try {
      final uid = AuthScope.read(context).user?.uid ?? '';
      final result = await _service.clearSafetyBackups(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.itemCount} local safety backup(s) deleted. '
            '${formatManagedBytes(result.bytesFreed)} freed.',
          ),
        ),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'HomeVault could not delete the local safety backups.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device storage & cleanup'),
        actions: [
          IconButton(
            tooltip: 'Refresh storage summary',
            onPressed: _busy || _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.storage_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'HomeVault-managed device storage',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Core appliance records stay on this device for offline '
                        'use. Cleanup only targets recoverable cloud-backed '
                        'document copies and HomeVault-managed safety backups.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_loading && summary == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_loadError != null && summary == null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('Storage summary unavailable'),
                    subtitle: const Text(
                      'Your HomeVault data has not been changed. Try refreshing.',
                    ),
                    trailing: IconButton(
                      tooltip: 'Retry',
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                )
              else if (summary != null) ...[
                _StorageTile(
                  key: const ValueKey('deviceStorageCloudBackedCopies'),
                  icon: Icons.cloud_done_outlined,
                  title: 'Cloud-backed local documents',
                  count: summary.cloudBackedDocumentCount,
                  bytes: summary.cloudBackedDocumentBytes,
                  subtitle:
                      'Safe to release from this device and download again later.',
                ),
                const SizedBox(height: 8),
                _StorageTile(
                  key: const ValueKey('deviceStorageLocalOnlyDocuments'),
                  icon: Icons.phone_android_outlined,
                  title: 'Local-only documents',
                  count: summary.localOnlyDocumentCount,
                  bytes: summary.localOnlyDocumentBytes,
                  subtitle: 'Protected from cleanup until a cloud copy exists.',
                ),
                const SizedBox(height: 8),
                _StorageTile(
                  key: const ValueKey('deviceStorageSafetyBackups'),
                  icon: Icons.health_and_safety_outlined,
                  title: 'Local safety backups',
                  count: summary.safetyBackupCount,
                  bytes: summary.safetyBackupBytes,
                  subtitle:
                      'Automatic local restore points created before destructive restores.',
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.data_usage_outlined),
                    title: const Text('Total managed file storage'),
                    trailing: Text(
                      formatManagedBytes(summary.totalManagedBytes),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Cleanup actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        key: const ValueKey(
                          'clearDownloadedDocumentCopiesTile',
                        ),
                        leading: const Icon(Icons.phonelink_erase_outlined),
                        title: const Text('Release downloaded document copies'),
                        subtitle: const Text(
                          'Removes only local copies that already have a cloud copy.',
                        ),
                        enabled: summary.hasRecoverableLocalCopies && !_busy,
                        onTap: _clearDownloadedCopies,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey('clearLocalSafetyBackupsTile'),
                        leading: const Icon(Icons.delete_sweep_outlined),
                        title: const Text('Delete local safety backups'),
                        subtitle: const Text(
                          'Does not delete cloud backups or exported ZIP files.',
                        ),
                        enabled: summary.hasSafetyBackups && !_busy,
                        onTap: _clearSafetyBackups,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'HomeVault never deletes local-only attachment files from this '
                  'cleanup screen. Cloud backups are not changed here. Exported '
                  'ZIP backups saved outside HomeVault remain under your control '
                  'in the device Files app.',
                ),
              ],
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _StorageTile extends StatelessWidget {
  const _StorageTile({
    super.key,
    required this.icon,
    required this.title,
    required this.count,
    required this.bytes,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final int count;
  final int bytes;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text('$subtitle\n$count item(s)'),
        isThreeLine: true,
        trailing: Text(
          formatManagedBytes(bytes),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
