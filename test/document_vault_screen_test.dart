import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/screens/documents/documents_screen.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/state/app_scope.dart';
import 'package:homevault/state/appliance_store.dart';

StoredDocument _document({
  required String id,
  required DocumentType type,
  required String title,
  required DateTime attachedAt,
  String localPath = '/documents/file.pdf',
  String cloudStoragePath = '',
  String notes = '',
}) {
  return StoredDocument(
    id: id,
    type: type,
    title: title,
    fileName: '$id.pdf',
    localPath: localPath,
    cloudStoragePath: cloudStoragePath,
    sizeBytes: 2048,
    attachedAt: attachedAt,
    notes: notes,
  );
}

Future<ApplianceStore> _store() async {
  final store = ApplianceStore(
    repository: MemoryApplianceRepository(
      initialAppliances: [
        Appliance(
          id: 'ac',
          name: 'Living room AC',
          category: 'Air Conditioner',
          brand: 'Daikin',
          invoiceDocument: _document(
            id: 'invoice',
            type: DocumentType.invoice,
            title: 'AC invoice',
            attachedAt: DateTime(2026, 8, 10),
          ),
          additionalDocuments: [
            _document(
              id: 'manual',
              type: DocumentType.userManual,
              title: 'AC manual',
              attachedAt: DateTime(2026, 8, 5),
              localPath: '',
              cloudStoragePath: 'users/test/appliances/ac/documents/manual.pdf',
              notes: 'Remote control instructions',
            ),
          ],
          createdAt: DateTime(2026, 8, 1),
        ),
        Appliance(
          id: 'washer',
          name: 'Washing machine',
          category: 'Washing Machine',
          brand: 'LG',
          additionalDocuments: [
            _document(
              id: 'service-report',
              type: DocumentType.serviceReport,
              title: 'Washer service report',
              attachedAt: DateTime(2026, 8, 20),
              localPath: '',
            ),
          ],
          createdAt: DateTime(2026, 8, 1),
        ),
      ],
    ),
  );
  await store.initialize();
  return store;
}

void main() {
  testWidgets('document vault summarizes, searches, and filters categories', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = await _store();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      AppScope(
        applianceStore: store,
        child: const MaterialApp(home: DocumentsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AC invoice'), findsOneWidget);
    expect(find.text('AC manual'), findsOneWidget);
    expect(find.text('Washer service report'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('documentVaultTotalMetric')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('documentVaultUnavailableMetric')),
      findsOneWidget,
    );

    final search = find.descendant(
      of: find.byKey(const ValueKey('documentVaultSearch')),
      matching: find.byType(EditableText),
    );
    expect(search, findsOneWidget);
    await tester.enterText(search, 'remote instructions');
    await tester.pumpAndSettle();

    expect(find.text('AC manual'), findsOneWidget);
    expect(find.text('AC invoice'), findsNothing);
    expect(find.text('Washer service report'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('documentVaultClearFilters')));
    await tester.pumpAndSettle();

    final serviceCategory = find.byKey(
      const ValueKey('documentVaultCategory_serviceAndMaintenance'),
    );
    await tester.ensureVisible(serviceCategory);
    await tester.pumpAndSettle();
    await tester.tap(serviceCategory);
    await tester.pumpAndSettle();

    expect(find.text('Washer service report'), findsOneWidget);
    expect(find.text('AC invoice'), findsNothing);
    expect(find.text('AC manual'), findsNothing);
  });

  testWidgets(
    'initial appliance link narrows the vault and details are visible',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = await _store();
      addTearDown(store.dispose);

      await tester.pumpWidget(
        AppScope(
          applianceStore: store,
          child: const MaterialApp(
            home: DocumentsScreen(initialApplianceId: 'ac'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AC invoice'), findsOneWidget);
      expect(find.text('AC manual'), findsOneWidget);
      expect(find.text('Washer service report'), findsNothing);

      final invoiceCard = find.byKey(
        const ValueKey('documentVaultCard_invoice'),
      );
      final menu = find.descendant(
        of: invoiceCard,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is PopupMenuButton<String> &&
              widget.tooltip?.startsWith('Document actions for AC invoice, ') ==
                  true &&
              widget.tooltip!.contains('Invoice • Living room AC') &&
              widget.tooltip!.contains('added 10 August 2026'),
          description: 'contextual AC invoice action menu',
        ),
      );
      expect(menu, findsOneWidget);

      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();

      expect(find.text('Document details'), findsOneWidget);
      expect(find.text('Linked appliance'), findsOneWidget);
      expect(find.text('Living room AC'), findsOneWidget);
      expect(find.textContaining('Purchase & warranty'), findsOneWidget);
      expect(find.text('Available on this device'), findsOneWidget);
    },
  );
}
