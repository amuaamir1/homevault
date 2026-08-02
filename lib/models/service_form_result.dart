import 'service_record.dart';
import 'stored_document.dart';

class ServiceFormResult {
  const ServiceFormResult({
    required this.applianceId,
    required this.record,
    this.originalRecord,
    this.documentsAdded = const [],
    this.documentsToDelete = const [],
  });

  final String applianceId;
  final ServiceRecord record;
  final ServiceRecord? originalRecord;
  final List<StoredDocument> documentsAdded;
  final List<StoredDocument> documentsToDelete;

  bool get isEditing => originalRecord != null;
}
