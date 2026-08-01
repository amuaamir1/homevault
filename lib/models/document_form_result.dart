import 'stored_document.dart';

class DocumentFormResult {
  const DocumentFormResult({
    required this.applianceId,
    required this.document,
    this.originalDocument,
  });

  final String applianceId;
  final StoredDocument document;
  final StoredDocument? originalDocument;

  bool get replacedFile =>
      originalDocument != null &&
      originalDocument!.localPath != document.localPath;
}
