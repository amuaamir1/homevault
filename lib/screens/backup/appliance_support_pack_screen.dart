import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/appliance.dart';
import '../../models/stored_document.dart';
import '../../services/homevault_error_presenter.dart';
import '../../services/homevault_support_pack_service.dart';
import '../../state/app_scope.dart';

class ApplianceSupportPackScreen extends StatefulWidget {
  const ApplianceSupportPackScreen({super.key, required this.applianceId});

  final String applianceId;

  @override
  State<ApplianceSupportPackScreen> createState() =>
      _ApplianceSupportPackScreenState();
}

class _ApplianceSupportPackScreenState
    extends State<ApplianceSupportPackScreen> {
  final _supportPackService = const HomeVaultSupportPackService();
  final Set<String> _selectedDocumentIds = <String>{};

  bool _includeServiceHistory = false;
  String? _busyMessage;

  bool get _isBusy => _busyMessage != null;

  String _availability(StoredDocument document) {
    if (document.isAvailableOnDevice && document.isAvailableInCloud) {
      return 'Ready • cloud backed up';
    }
    if (document.isAvailableOnDevice) return 'Ready on this device';
    if (document.isAvailableInCloud) return 'Cloud only • downloads when saved';
    return 'File unavailable';
  }

  bool _canSelect(StoredDocument document) =>
      document.isAvailableOnDevice || document.isAvailableInCloud;

  int _selectedBytes(Appliance appliance) {
    return appliance.allDocuments
        .where((document) => _selectedDocumentIds.contains(document.id))
        .fold<int>(0, (total, document) => total + document.sizeBytes);
  }

  String _formattedBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  void _toggleDocument(StoredDocument document, bool selected) {
    if (selected &&
        !_selectedDocumentIds.contains(document.id) &&
        _selectedDocumentIds.length >=
            HomeVaultSupportPackService.maximumDocuments) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A support pack can include up to 25 documents.'),
        ),
      );
      return;
    }

    setState(() {
      if (selected) {
        _selectedDocumentIds.add(document.id);
      } else {
        _selectedDocumentIds.remove(document.id);
      }
    });
  }

  void _selectAllAvailable(Appliance appliance) {
    final available = appliance.allDocuments
        .where(_canSelect)
        .take(HomeVaultSupportPackService.maximumDocuments)
        .map((document) => document.id)
        .toSet();
    setState(() {
      _selectedDocumentIds
        ..clear()
        ..addAll(available);
    });
  }

  Future<StoredDocument> _prepareDocument(
    Appliance appliance,
    StoredDocument document,
  ) async {
    final store = AppScope.read(context);

    if (document.isAvailableOnDevice) {
      final file = File(document.localPath);
      if (await file.exists()) return document;
    }

    if (!document.isAvailableInCloud) {
      throw HomeVaultSupportPackException(
        '${document.displayTitle} is unavailable. Edit the document and choose the file again.',
      );
    }

    return store.downloadDocument(appliance.id, document.id);
  }

  Future<void> _saveSupportPack() async {
    if (_isBusy) return;

    final store = AppScope.read(context);
    final initialAppliance = store.applianceById(widget.applianceId);
    if (initialAppliance == null) {
      showHomeVaultError(
        context,
        StateError('Appliance missing'),
        fallback: 'The appliance could not be found.',
      );
      return;
    }
    var appliance = initialAppliance;

    final selected = appliance.allDocuments
        .where((document) => _selectedDocumentIds.contains(document.id))
        .toList(growable: false);
    final estimatedBytes = selected.fold<int>(
      0,
      (total, document) => total + document.sizeBytes,
    );
    if (estimatedBytes > HomeVaultSupportPackService.maximumSupportPackBytes) {
      showHomeVaultError(
        context,
        const HomeVaultSupportPackException(
          'The selected documents are too large for one support pack. Select fewer files and try again.',
        ),
      );
      return;
    }

    setState(() => _busyMessage = 'Preparing support pack...');

    try {
      final prepared = <StoredDocument>[];
      for (var index = 0; index < selected.length; index++) {
        if (!mounted) return;
        setState(() {
          _busyMessage =
              'Preparing document ${index + 1} of ${selected.length}...';
        });
        prepared.add(await _prepareDocument(appliance, selected[index]));
      }

      appliance = store.applianceById(widget.applianceId) ?? appliance;
      if (!mounted) return;
      setState(() => _busyMessage = 'Creating support pack...');

      final result = await _supportPackService.saveSupportPack(
        appliance: appliance,
        documents: prepared,
        includeServiceHistory: _includeServiceHistory,
      );
      if (!mounted || !result.saved) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Support pack saved with ${result.documentCount} document(s). You can share it later from Files.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The support pack could not be saved. Try again.',
      );
    } finally {
      if (mounted) setState(() => _busyMessage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final appliance = store.applianceById(widget.applianceId);

    if (appliance == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Appliance support pack')),
        body: const Center(
          child: Text('This appliance is no longer available.'),
        ),
      );
    }

    final documents = appliance.allDocuments;
    final selectedBytes = _selectedBytes(appliance);

    return PopScope(
      canPop: !_isBusy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Appliance support pack')),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appliance.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [appliance.brand, appliance.modelNumber]
                              .where((value) => value.trim().isNotEmpty)
                              .join(' • '),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'The appliance summary PDF is always included. Select only the document files you want to provide to a service provider or manufacturer.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SwitchListTile(
                    key: const ValueKey('p17SupportPackServiceHistoryToggle'),
                    value: _includeServiceHistory,
                    onChanged: _isBusy
                        ? null
                        : (value) =>
                              setState(() => _includeServiceHistory = value),
                    title: const Text('Include service history'),
                    subtitle: const Text(
                      'Off by default. Turn this on only when the recipient needs your recorded service history.',
                    ),
                    secondary: const Icon(Icons.build_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Documents',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: _isBusy || documents.isEmpty
                          ? null
                          : () => _selectAllAvailable(appliance),
                      child: const Text('Select available'),
                    ),
                    if (_selectedDocumentIds.isNotEmpty)
                      TextButton(
                        onPressed: _isBusy
                            ? null
                            : () => setState(_selectedDocumentIds.clear),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                Text(
                  '${_selectedDocumentIds.length} selected • ${_formattedBytes(selectedBytes)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (documents.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.description_outlined),
                      title: Text('No documents saved for this appliance'),
                      subtitle: Text(
                        'You can still save a summary-only support pack.',
                      ),
                    ),
                  )
                else
                  ...documents.map(
                    (document) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: CheckboxListTile(
                        key: ValueKey('p17SupportPackDocument_${document.id}'),
                        value: _selectedDocumentIds.contains(document.id),
                        onChanged: !_canSelect(document) || _isBusy
                            ? null
                            : (value) =>
                                  _toggleDocument(document, value ?? false),
                        title: Text(document.displayTitle),
                        subtitle: Text(
                          '${document.fileName} • ${document.formattedSize}\n${_availability(document)}',
                        ),
                        secondary: Icon(
                          document.isAvailableOnDevice
                              ? Icons.phone_android_outlined
                              : document.isAvailableInCloud
                              ? Icons.cloud_outlined
                              : Icons.warning_amber_outlined,
                        ),
                        isThreeLine: true,
                        controlAffinity: ListTileControlAffinity.trailing,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.privacy_tip_outlined),
                    title: Text('Privacy'),
                    subtitle: Text(
                      'A support pack is not a HomeVault backup. It contains the summary choices and document files selected here, and is not encrypted after you save it.',
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('p17SaveSupportPackButton'),
                    onPressed: _isBusy ? null : _saveSupportPack,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Save support pack'),
                  ),
                ),
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
}
