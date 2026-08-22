import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/admin_feedback.dart';
import '../../models/beta_feedback.dart';
import '../../services/feedback_admin_service.dart';
import '../../services/homevault_error_presenter.dart';

class FeedbackDetailScreen extends StatefulWidget {
  const FeedbackDetailScreen({
    super.key,
    required this.item,
    required this.adminUid,
    required this.repository,
  });

  final AdminFeedbackItem item;
  final String adminUid;
  final FeedbackAdminRepository repository;

  @override
  State<FeedbackDetailScreen> createState() => _FeedbackDetailScreenState();
}

class _FeedbackDetailScreenState extends State<FeedbackDetailScreen> {
  late FeedbackWorkflowStatus _status;
  late FeedbackPriority _priority;
  late final TextEditingController _noteController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.item.status;
    _priority = widget.item.priority;
    _noteController = TextEditingController(text: widget.item.adminNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.updateFeedback(
        item: widget.item,
        adminUid: widget.adminUid,
        status: _status,
        priority: _priority,
        adminNote: _noteController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Feedback updated.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'Feedback could not be updated. Please try again.',
        actionLabel: 'Retry',
        onAction: _save,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(item.category.label)),
                      Chip(label: Text(item.isLegacy ? 'Legacy' : 'Central')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.message,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Submitted by',
            rows: [
              ('User', item.submitterLabel),
              ('UID', item.uid),
              ('Submitted', _formatDateTime(item.createdAt)),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'App & device',
            rows: [
              ('App version', _version(item)),
              ('Release', item.releaseNumber),
              ('Platform', item.platform),
              ('Device', _device(item)),
              ('Android', _android(item)),
            ],
          ),
          if (item.hasScreenshot) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Screenshot',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(item.screenshotBase64!),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Text(
                              'The screenshot could not be displayed.',
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<FeedbackWorkflowStatus>(
            initialValue: _status,
            decoration: const InputDecoration(
              labelText: 'Status',
              prefixIcon: Icon(Icons.task_alt_outlined),
            ),
            items: FeedbackWorkflowStatus.values
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _status = value);
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FeedbackPriority>(
            initialValue: _priority,
            decoration: const InputDecoration(
              labelText: 'Priority',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            items: FeedbackPriority.values
                .map(
                  (priority) => DropdownMenuItem(
                    value: priority,
                    child: Text(priority.label),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _priority = value);
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Admin note',
              alignLabelWithHint: true,
              hintText: 'Add investigation notes, follow-up, or resolution.',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save changes'),
          ),
        ],
      ),
    );
  }

  String _version(AdminFeedbackItem item) {
    final version = item.appVersion.trim();
    final build = item.buildNumber.trim();
    if (version.isEmpty && build.isEmpty) return 'Not available';
    if (build.isEmpty) return version;
    if (version.isEmpty) return 'Build $build';
    return '$version ($build)';
  }

  String _device(AdminFeedbackItem item) {
    final text = '${item.deviceManufacturer} ${item.deviceModel}'.trim();
    return text.isEmpty ? 'Not available' : text;
  }

  String _android(AdminFeedbackItem item) {
    final version = item.androidVersion.trim();
    final sdk = item.androidSdk;
    if (version.isEmpty && sdk == null) return 'Not available';
    if (sdk == null) return version;
    if (version.isEmpty) return 'SDK $sdk';
    return '$version (SDK $sdk)';
  }

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final usefulRows = rows.where((row) => row.$2.trim().isNotEmpty).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...usefulRows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        row.$1,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(child: SelectableText(row.$2)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
