import 'package:flutter/material.dart';

import '../models/stored_document.dart';

class StoredDocumentTile extends StatelessWidget {
  const StoredDocumentTile({
    super.key,
    required this.document,
    required this.title,
    required this.subtitle,
    required this.onOpen,
    this.onEdit,
    this.onDelete,
  });

  final StoredDocument document;
  final String title;
  final String subtitle;
  final VoidCallback onOpen;
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

  @override
  Widget build(BuildContext context) {
    final reference = document.reference.trim();
    final fileDetails = [
      document.fileName,
      document.formattedSize,
      if (reference.isNotEmpty) 'Ref: $reference',
    ].join(' • ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(_icon)),
      title: Text(title),
      subtitle: Text('$subtitle\n$fileDetails'),
      isThreeLine: true,
      trailing: onEdit == null && onDelete == null
          ? IconButton(
              tooltip: 'Open document',
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new),
            )
          : PopupMenuButton<String>(
              tooltip: 'Document actions',
              onSelected: (action) {
                switch (action) {
                  case 'open':
                    onOpen();
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
                const PopupMenuItem(
                  value: 'open',
                  child: ListTile(
                    leading: Icon(Icons.open_in_new),
                    title: Text('Open'),
                  ),
                ),
                if (onEdit != null)
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
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
      onTap: onOpen,
    );
  }
}
