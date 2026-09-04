import 'package:flutter/material.dart';

import '../accessibility/homevault_accessibility.dart';
import '../models/stored_document.dart';

class StoredDocumentTile extends StatelessWidget {
  const StoredDocumentTile({
    super.key,
    required this.document,
    required this.title,
    required this.subtitle,
    required this.onOpen,
    this.onDetails,
    this.onSaveCopy,
    this.onEdit,
    this.onDelete,
  });

  final StoredDocument document;
  final String title;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback? onDetails;
  final VoidCallback? onSaveCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  IconData get _icon {
    switch (document.extension) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  bool get _canOpen =>
      document.isAvailableOnDevice || document.isAvailableInCloud;

  String get _availabilityText {
    if (document.isAvailableOnDevice && document.isAvailableInCloud) {
      return 'On device + cloud';
    }
    if (document.isAvailableOnDevice) return 'On device';
    if (document.isAvailableInCloud) return 'Cloud only';
    return 'File unavailable';
  }

  String _spokenDate(DateTime value) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final reference = document.reference.trim();
    final fileDetails = [
      document.fileName,
      document.formattedSize,
      _availabilityText,
      if (reference.isNotEmpty) 'Ref: $reference',
    ].join(' • ');

    final accessibleDetails = [
      subtitle,
      document.formattedSize,
      _availabilityText,
      if (reference.isNotEmpty) 'Reference: $reference',
    ].join(', ');

    final normalizedTitle = title.trim();
    final normalizedSubtitle = subtitle.trim();
    final documentContext = [
      normalizedTitle,
      if (normalizedSubtitle.isNotEmpty &&
          normalizedSubtitle != normalizedTitle)
        normalizedSubtitle,
      'added ${_spokenDate(document.attachedAt)}',
    ].join(', ');

    final hasActions =
        onDetails != null ||
        onSaveCopy != null ||
        onEdit != null ||
        onDelete != null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ExcludeSemantics(child: CircleAvatar(child: Icon(_icon))),
      title: Text(title),
      subtitle: Semantics(
        label: accessibleDetails,
        excludeSemantics: true,
        child: Text('$subtitle\n$fileDetails'),
      ),
      isThreeLine: true,
      trailing: !hasActions
          ? IconButton(
              tooltip: _canOpen
                  ? HomeVaultAccessibility.contextualAction(
                      'Open document',
                      documentContext,
                    )
                  : '$title file unavailable',
              onPressed: _canOpen ? onOpen : null,
              icon: Icon(
                _canOpen ? Icons.open_in_new : Icons.warning_amber_outlined,
              ),
            )
          : PopupMenuButton<String>(
              tooltip: HomeVaultAccessibility.contextualAction(
                'Document actions',
                documentContext,
              ),
              onSelected: (action) {
                switch (action) {
                  case 'open':
                    onOpen();
                    break;
                  case 'details':
                    onDetails?.call();
                    break;
                  case 'saveCopy':
                    onSaveCopy?.call();
                    break;
                  case 'edit':
                    onEdit?.call();
                    break;
                  case 'delete':
                    onDelete?.call();
                    break;
                }
              },
              itemBuilder: (context) => [
                if (_canOpen)
                  PopupMenuItem(
                    value: 'open',
                    child: Semantics(
                      label: 'Open $documentContext',
                      excludeSemantics: true,
                      child: const ListTile(
                        leading: Icon(Icons.open_in_new),
                        title: Text('Open'),
                      ),
                    ),
                  )
                else
                  const PopupMenuItem(
                    enabled: false,
                    child: ListTile(
                      leading: Icon(Icons.warning_amber_outlined),
                      title: Text('File unavailable'),
                    ),
                  ),
                if (onDetails != null)
                  PopupMenuItem(
                    value: 'details',
                    child: Semantics(
                      label: 'View details for $documentContext',
                      excludeSemantics: true,
                      child: const ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('View details'),
                      ),
                    ),
                  ),
                if (onSaveCopy != null && _canOpen)
                  PopupMenuItem(
                    value: 'saveCopy',
                    child: Semantics(
                      label: 'Save a copy of $documentContext',
                      excludeSemantics: true,
                      child: const ListTile(
                        leading: Icon(Icons.download_outlined),
                        title: Text('Save a copy'),
                      ),
                    ),
                  ),
                if (onEdit != null)
                  PopupMenuItem(
                    value: 'edit',
                    child: Semantics(
                      label: 'Edit metadata for $documentContext',
                      excludeSemantics: true,
                      child: const ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit metadata'),
                      ),
                    ),
                  ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: 'delete',
                    child: Semantics(
                      label: 'Delete $documentContext',
                      excludeSemantics: true,
                      child: const ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete'),
                      ),
                    ),
                  ),
              ],
            ),
      onTap: _canOpen ? onOpen : onDetails,
    );
  }
}
