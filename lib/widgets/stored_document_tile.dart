import 'package:flutter/material.dart';

import '../models/stored_document.dart';

class StoredDocumentTile extends StatelessWidget {
  const StoredDocumentTile({
    super.key,
    required this.document,
    required this.title,
    required this.subtitle,
    required this.onOpen,
    this.onRetryUpload,
    this.onEdit,
    this.onDelete,
  });

  final StoredDocument document;
  final String title;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback? onRetryUpload;
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

  String get _availabilityText {
    if (document.isAvailableOnDevice && document.isAvailableInCloud) {
      return '${document.formattedSize} • On this device & cloud';
    }
    if (document.isAvailableOnDevice) {
      return '${document.formattedSize} • Cloud upload pending';
    }
    if (document.isAvailableInCloud) {
      return '${document.formattedSize} • Available in cloud';
    }
    return '${document.formattedSize} • File unavailable';
  }

  bool get _canOpen =>
      document.isAvailableOnDevice || document.isAvailableInCloud;

  @override
  Widget build(BuildContext context) {
    final reference = document.reference.trim();
    final fileDetails = [
      document.fileName,
      _availabilityText,
      if (reference.isNotEmpty) 'Ref: $reference',
    ].join(' • ');

    final hasActions =
        onRetryUpload != null || onEdit != null || onDelete != null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(_icon)),
      title: Text(title),
      subtitle: Text('$subtitle\n$fileDetails'),
      isThreeLine: true,
      trailing: !hasActions
          ? IconButton(
              tooltip: document.isAvailableOnDevice
                  ? 'Open document'
                  : document.isAvailableInCloud
                  ? 'Download and open'
                  : 'File unavailable',
              onPressed: _canOpen ? onOpen : null,
              icon: Icon(
                document.isAvailableOnDevice
                    ? Icons.open_in_new
                    : document.isAvailableInCloud
                    ? Icons.cloud_download_outlined
                    : Icons.cloud_off_outlined,
              ),
            )
          : PopupMenuButton<String>(
              tooltip: 'Document actions',
              onSelected: (action) {
                switch (action) {
                  case 'open':
                    onOpen();
                    break;
                  case 'upload':
                    onRetryUpload?.call();
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
                    child: ListTile(
                      leading: Icon(
                        document.isAvailableOnDevice
                            ? Icons.open_in_new
                            : Icons.cloud_download_outlined,
                      ),
                      title: Text(
                        document.isAvailableOnDevice
                            ? 'Open'
                            : 'Download and open',
                      ),
                    ),
                  )
                else
                  const PopupMenuItem(
                    enabled: false,
                    child: ListTile(
                      leading: Icon(Icons.cloud_off_outlined),
                      title: Text('File unavailable'),
                    ),
                  ),
                if (onRetryUpload != null &&
                    document.isAvailableOnDevice &&
                    !document.isAvailableInCloud)
                  const PopupMenuItem(
                    value: 'upload',
                    child: ListTile(
                      leading: Icon(Icons.cloud_upload_outlined),
                      title: Text('Retry cloud upload'),
                    ),
                  ),
                if (onEdit != null)
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit metadata'),
                    ),
                  ),
                if (onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                    ),
                  ),
              ],
            ),
      onTap: _canOpen ? onOpen : null,
    );
  }
}
