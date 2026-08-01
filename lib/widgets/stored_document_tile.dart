import 'package:flutter/material.dart';

import '../models/stored_document.dart';

class StoredDocumentTile extends StatelessWidget {
  const StoredDocumentTile({
    super.key,
    required this.document,
    required this.title,
    required this.subtitle,
    required this.onOpen,
  });

  final StoredDocument document;
  final String title;
  final String subtitle;
  final VoidCallback onOpen;

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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(_icon)),
      title: Text(title),
      subtitle: Text('$subtitle\n${document.fileName} • ${document.formattedSize}'),
      isThreeLine: true,
      trailing: const Icon(Icons.open_in_new),
      onTap: onOpen,
    );
  }
}
