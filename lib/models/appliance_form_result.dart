import 'appliance.dart';
import 'stored_document.dart';

class ApplianceFormResult {
  const ApplianceFormResult({
    required this.appliance,
    this.documentsAdded = const [],
    this.documentsToDelete = const [],
  });

  final Appliance appliance;
  final List<StoredDocument> documentsAdded;
  final List<StoredDocument> documentsToDelete;
}
