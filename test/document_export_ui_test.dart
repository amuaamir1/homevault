import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/widgets/stored_document_tile.dart';

void main() {
  testWidgets('document action menu exposes Save a copy', (tester) async {
    var saveRequested = false;
    final document = StoredDocument(
      id: 'invoice',
      type: DocumentType.invoice,
      title: 'Invoice',
      fileName: 'invoice.pdf',
      localPath: '/documents/invoice.pdf',
      sizeBytes: 1024,
      attachedAt: DateTime(2026, 8, 24),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoredDocumentTile(
            document: document,
            title: 'Invoice',
            subtitle: 'Invoice • Living room AC',
            onOpen: () {},
            onDetails: () {},
            onSaveCopy: () => saveRequested = true,
          ),
        ),
      ),
    );

    final menu = find.byWidgetPredicate(
      (widget) =>
          widget is PopupMenuButton<String> &&
          widget.tooltip?.startsWith('Document actions for Invoice, ') ==
              true &&
          widget.tooltip!.contains('Invoice • Living room AC') &&
          widget.tooltip!.contains('added 24 August 2026'),
      description: 'contextual Invoice document action menu',
    );
    expect(menu, findsOneWidget);

    await tester.tap(menu);
    await tester.pumpAndSettle();

    expect(find.text('Save a copy'), findsOneWidget);
    await tester.tap(find.text('Save a copy'));
    await tester.pumpAndSettle();
    expect(saveRequested, isTrue);
  });
}
