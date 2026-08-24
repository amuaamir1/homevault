import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/screens/backup/appliance_support_pack_screen.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/state/app_scope.dart';
import 'package:homevault/state/appliance_store.dart';

void main() {
  testWidgets(
    'support pack starts privacy-first and lets user choose documents',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final appliance = Appliance(
        id: 'ac-1',
        name: 'Living room AC',
        category: 'Air Conditioner',
        brand: 'Daikin',
        createdAt: DateTime(2026, 8, 24),
        invoiceDocument: StoredDocument(
          id: 'invoice',
          type: DocumentType.invoice,
          title: 'Invoice',
          fileName: 'invoice.pdf',
          localPath: '/documents/invoice.pdf',
          sizeBytes: 2048,
          attachedAt: DateTime(2026, 8, 24),
        ),
        warrantyDocument: StoredDocument(
          id: 'warranty',
          type: DocumentType.warrantyCard,
          title: 'Warranty card',
          fileName: 'warranty.pdf',
          localPath: '',
          cloudStoragePath: 'users/u1/documents/warranty.pdf',
          sizeBytes: 1024,
          attachedAt: DateTime(2026, 8, 24),
        ),
      );
      final store = ApplianceStore(
        repository: MemoryApplianceRepository(initialAppliances: [appliance]),
      );
      await store.initialize();
      addTearDown(store.dispose);

      await tester.pumpWidget(
        AppScope(
          applianceStore: store,
          child: const MaterialApp(
            home: ApplianceSupportPackScreen(applianceId: 'ac-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Appliance support pack'), findsOneWidget);
      expect(find.text('Living room AC'), findsOneWidget);
      expect(find.textContaining('always included'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('p17SupportPackServiceHistoryToggle')),
        findsOneWidget,
      );
      final toggle = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('p17SupportPackServiceHistoryToggle')),
      );
      expect(toggle.value, isFalse);
      expect(
        find.byKey(const ValueKey('p17SupportPackDocument_invoice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('p17SupportPackDocument_warranty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('p17SaveSupportPackButton')),
        findsOneWidget,
      );
    },
  );
}
