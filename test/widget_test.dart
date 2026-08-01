import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/app.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/state/appliance_store.dart';

Future<ApplianceStore> _createStore({
  List<Appliance> initialAppliances = const [],
}) async {
  final store = ApplianceStore(
    repository: MemoryApplianceRepository(initialAppliances: initialAppliances),
  );
  await store.initialize();
  return store;
}

void main() {
  testWidgets('HomeVault starts on the dashboard', (tester) async {
    final store = await _createStore();
    addTearDown(store.dispose);

    await tester.pumpWidget(HomeVaultApp(applianceStore: store));
    await tester.pumpAndSettle();

    expect(find.text('HomeVault'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Appliances'), findsWidgets);
    expect(find.text('Documents'), findsWidgets);
    expect(find.text('Support'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('user can open the add appliance form', (tester) async {
    final store = await _createStore();
    addTearDown(store.dispose);

    await tester.pumpWidget(HomeVaultApp(applianceStore: store));
    await tester.pumpAndSettle();

    final addApplianceButton = find.text('Add appliance').first;
    expect(addApplianceButton, findsOneWidget);

    await tester.ensureVisible(addApplianceButton);
    await tester.pumpAndSettle();
    await tester.tap(addApplianceButton);
    await tester.pumpAndSettle();

    expect(find.text('Appliance details'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Appliance name *'),
      findsOneWidget,
    );

    final applianceForm = find.byType(ListView);
    final saveButton = find.text('Save appliance');

    expect(applianceForm, findsOneWidget);
    await tester.dragUntilVisible(
      saveButton,
      applianceForm,
      const Offset(0, -500),
      maxIteration: 10,
    );
    await tester.pumpAndSettle();

    expect(saveButton, findsOneWidget);
  });

  testWidgets('document vault shows saved appliance documents', (tester) async {
    final appliance = Appliance(
      id: 'ac-1',
      name: 'Living room AC',
      category: 'Air Conditioner',
      brand: 'Daikin',
      additionalDocuments: [
        StoredDocument(
          id: 'manual-1',
          type: DocumentType.userManual,
          title: 'AC manual',
          fileName: 'manual.pdf',
          localPath: '/documents/manual.pdf',
          sizeBytes: 1024,
          attachedAt: DateTime(2026, 8, 1),
        ),
      ],
      createdAt: DateTime(2026, 8, 1),
    );
    final store = await _createStore(initialAppliances: [appliance]);
    addTearDown(store.dispose);

    await tester.pumpWidget(HomeVaultApp(applianceStore: store));
    await tester.pumpAndSettle();

    final documentsDestination = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Documents'),
    );
    await tester.tap(documentsDestination);
    await tester.pumpAndSettle();

    expect(find.text('AC manual'), findsOneWidget);
    expect(find.textContaining('Living room AC'), findsOneWidget);
    expect(find.text('Add document'), findsOneWidget);
  });

  testWidgets('support directory shows direct contact actions', (tester) async {
    final appliance = Appliance(
      id: 'ac-support-1',
      name: 'Bedroom AC',
      category: 'Air Conditioner',
      brand: 'Daikin',
      supportProvider: 'Daikin Care',
      supportPhone: '+966 11 123 4567',
      supportEmail: 'care@example.com',
      supportWebsite: 'support.example.com',
      supportNotes: 'Sunday to Thursday',
      createdAt: DateTime(2026, 8, 1),
    );
    final store = await _createStore(initialAppliances: [appliance]);
    addTearDown(store.dispose);

    await tester.pumpWidget(HomeVaultApp(applianceStore: store));
    await tester.pumpAndSettle();

    final supportDestination = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Support'),
    );
    await tester.tap(supportDestination);
    await tester.pumpAndSettle();

    expect(find.text('Bedroom AC'), findsOneWidget);
    expect(find.text('Daikin Care'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Email'), findsWidgets);
    expect(find.text('Website'), findsWidgets);
    expect(find.text('Sunday to Thursday'), findsOneWidget);
  });
}
