import 'package:flutter/material.dart';

import '../models/stored_document.dart';

class DocumentAttachmentField extends StatelessWidget {
  const DocumentAttachmentField({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.document,
    required this.isLoading,
    required this.onPick,
    required this.onRemove,
  });

  final String title;
  final String description;
  final IconData icon;
  final StoredDocument? document;
  final bool isLoading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final selectedDocument = document;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: selectedDocument == null
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(child: Icon(icon)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: isLoading ? null : onPick,
                          icon: isLoading
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_file_outlined),
                          label: Text(
                            isLoading ? 'Selecting...' : 'Choose file',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  const CircleAvatar(
                    child: Icon(Icons.insert_drive_file_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          selectedDocument.fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          selectedDocument.formattedSize,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          selectedDocument.isAvailableOnDevice &&
                                  selectedDocument.isAvailableInCloud
                              ? 'Available on this device and in cloud'
                              : selectedDocument.isAvailableOnDevice
                              ? 'Available on this device • cloud upload pending'
                              : selectedDocument.isAvailableInCloud
                              ? 'Available in cloud • download when needed'
                              : 'File not available on this device or in cloud',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Replace file',
                    onPressed: isLoading ? null : onPick,
                    icon: const Icon(Icons.change_circle_outlined),
                  ),
                  IconButton(
                    tooltip: 'Remove file',
                    onPressed: isLoading ? null : onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
      ),
    );
  }
}
