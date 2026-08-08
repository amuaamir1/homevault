import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/widgets/stored_document_tile.dart';

void main() {
  group('document cloud metadata', () {
    test('removes the device-specific path but preserves metadata', () {
      final document = StoredDocument(
        id: 'invoice-1',
        type: DocumentType.invoice,
        title: 'Purchase invoice',
        reference: 'INV-1001',
        notes: 'Original invoice',
        fileName: 'invoice.pdf',
        localPath: '/device/a/invoice.pdf',
        sizeBytes: 2048,
        attachedAt: DateTime(2026, 8, 8),
      );

      final cloudJson = document.toCloudMetadataJson();
      final cloudDocument = StoredDocument.fromJson(cloudJson);

      expect(cloudJson['localPath'], '');
      expect(cloudDocument.id, 'invoice-1');
      expect(cloudDocument.type, DocumentType.invoice);
      expect(cloudDocument.title, 'Purchase invoice');
      expect(cloudDocument.reference, 'INV-1001');
      expect(cloudDocument.fileName, 'invoice.pdf');
      expect(cloudDocument.sizeBytes, 2048);
      expect(cloudDocument.isAvailableOnDevice, isFalse);
    });

    test('restores a local path only for the same document id', () {
      final cloudDocument = StoredDocument(
        id: 'manual-1',
        type: DocumentType.userManual,
        title: 'Manual',
        fileName: 'manual.pdf',
        localPath: '',
        sizeBytes: 4096,
        attachedAt: DateTime(2026, 8, 8),
      );
      final localDocument = cloudDocument.copyWith(
        localPath: '/device/b/manual.pdf',
      );

      final merged = cloudDocument.withLocalAvailabilityFrom(localDocument);

      expect(merged.localPath, '/device/b/manual.pdf');
      expect(merged.isAvailableOnDevice, isTrue);
    });

    test('does not borrow a path from a different document', () {
      final cloudDocument = StoredDocument(
        id: 'manual-1',
        fileName: 'manual.pdf',
        localPath: '',
        sizeBytes: 4096,
        attachedAt: DateTime(2026, 8, 8),
      );
      final otherDocument = StoredDocument(
        id: 'manual-2',
        fileName: 'manual.pdf',
        localPath: '/device/b/manual.pdf',
        sizeBytes: 4096,
        attachedAt: DateTime(2026, 8, 8),
      );

      final merged = cloudDocument.withLocalAvailabilityFrom(otherDocument);

      expect(merged.localPath, isEmpty);
      expect(merged.isAvailableOnDevice, isFalse);
    });
  });

  testWidgets('cloud-only document shows download availability', (
  tester,
) async {
  final document = StoredDocument(
    id: 'invoice-cloud',
    type: DocumentType.invoice,
    title: 'Invoice',
    fileName: 'invoice.pdf',
    localPath: '',
    sizeBytes: 1024,
    attachedAt: DateTime(2026, 8, 8),
    cloudStoragePath:
        'users/user-1/appliances/appliance-1/documents/'
        'invoice-cloud/invoice.pdf',
    cloudContentType: 'application/pdf',
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StoredDocumentTile(
          document: document,
          title: 'Invoice',
          subtitle: 'Invoice • Bedroom AC',
          onOpen: () {},
        ),
      ),
    ),
  );

  expect(
    find.textContaining('Available in cloud'),
    findsOneWidget,
  );

  expect(
    find.byTooltip('Download and open'),
    findsOneWidget,
  );
});

testWidgets('document without local or cloud file shows unavailable', (
  tester,
) async {
  final document = StoredDocument(
    id: 'invoice-unavailable',
    type: DocumentType.invoice,
    title: 'Invoice',
    fileName: 'invoice.pdf',
    localPath: '',
    sizeBytes: 1024,
    attachedAt: DateTime(2026, 8, 8),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StoredDocumentTile(
          document: document,
          title: 'Invoice',
          subtitle: 'Invoice • Bedroom AC',
          onOpen: () {},
        ),
      ),
    ),
  );

  expect(
    find.textContaining('File unavailable'),
    findsOneWidget,
  );

  expect(
    find.byTooltip('File unavailable'),
    findsOneWidget,
  );
});
}
