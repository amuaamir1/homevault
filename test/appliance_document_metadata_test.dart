import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';

void main() {
  test('keeps cloud document metadata when local path is empty', () {
    final appliance = Appliance.fromJson({
      'id': 'appliance-1',
      'name': 'Test appliance',
      'category': 'Other',
      'brand': 'Test brand',
      'createdAt': DateTime(2026, 8, 8).toIso8601String(),
      'additionalDocuments': [
        {
          'id': 'cloud-document-1',
          'type': 'other',
          'title': 'Cloud document',
          'fileName': 'document.pdf',
          'localPath': '',
          'sizeBytes': 1024,
          'attachedAt': DateTime(2026, 8, 8).toIso8601String(),
        },
      ],
    });

    expect(appliance.additionalDocuments.length, 1);
    expect(appliance.additionalDocuments.first.id, 'cloud-document-1');
    expect(appliance.additionalDocuments.first.fileName, 'document.pdf');
    expect(appliance.additionalDocuments.first.localPath, isEmpty);
  });
}