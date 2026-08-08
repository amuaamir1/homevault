import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/app.dart';
import 'package:homevault/auth/auth_controller.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/service_record.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/models/user_profile.dart';
import 'package:homevault/profile/profile_controller.dart';
import 'package:homevault/security/app_lock_controller.dart';
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

Future<void> _pumpHomeVault(WidgetTester tester, ApplianceStore store) async {
  const testUid = 'test-user';

  // Bind the test database before building the app so the startup gate
  // does not remain on an animated loading screen.
  await store.bindOwner(testUid);

  final lockController = AppLockController.unlockedForTesting(uid: testUid);

  final authController = AuthController.authenticatedForTesting(
    uid: testUid,
    phoneNumber: '+919876543210',
  );

  final profileController = ProfileController.loadedForTesting(
    UserProfile(
      uid: testUid,
      fullName: 'Aamir Test',
      phoneNumber: '+919876543210',
      addressLine1: '12 Test Street',
      state: 'Delhi',
      city: 'New Delhi',
      pinCode: '110001',
    ),
  );

  addTearDown(lockController.dispose);
  addTearDown(authController.dispose);
  addTearDown(profileController.dispose);

  await tester.pumpWidget(
    HomeVaultApp(
      applianceStore: store,
      appLockController: lockController,
      authController: authController,
      profileController: profileController,
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('HomeVault starts on the dashboard', (tester) async {
    final store = await _createStore();
    addTearDown(store.dispose);

    await _pumpHomeVault(tester, store);

    expect(find.text('HomeVault'), findsOneWidget);
    expect(find.text('Welcome Aamir'), findsOneWidget);
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

    await _pumpHomeVault(tester, store);

    final addApplianceButton = find.byTooltip('Add appliance');
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

    await _pumpHomeVault(tester, store);

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

  testWidgets('support directory groups and expands support details', (
    tester,
  ) async {
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

    await _pumpHomeVault(tester, store);

    final supportDestination = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Support'),
    );
    await tester.tap(supportDestination);
    await tester.pumpAndSettle();

    expect(find.text('Air Conditioner'), findsOneWidget);
    expect(find.text('1 appliance'), findsOneWidget);
    expect(find.text('Bedroom AC'), findsNothing);
    expect(find.text('Call'), findsNothing);
    expect(find.text('Sunday to Thursday'), findsNothing);

    await tester.tap(find.text('Air Conditioner'));
    await tester.pumpAndSettle();

    expect(find.text('Bedroom AC'), findsOneWidget);
    expect(find.text('Daikin Care'), findsOneWidget);
    expect(find.text('Call'), findsNothing);
    expect(find.text('Sunday to Thursday'), findsNothing);

    await tester.tap(find.text('Bedroom AC'));
    await tester.pumpAndSettle();

    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Email'), findsWidgets);
    expect(find.text('Website'), findsWidgets);
    expect(find.text('Sunday to Thursday'), findsOneWidget);
  });

  testWidgets('warranty center shows warranty status and reminders', (
    tester,
  ) async {
    final appliance = Appliance(
      id: 'ac-warranty-1',
      name: 'Family room AC',
      category: 'Air Conditioner',
      brand: 'Daikin',
      warrantyProvider: 'Daikin Care',
      warrantyExpiryDate: DateTime(2028, 8, 1),
      warrantyReminderEnabled: true,
      warrantyReminderDaysBefore: 30,
      createdAt: DateTime(2026, 8, 1),
    );

    final store = await _createStore(initialAppliances: [appliance]);
    addTearDown(store.dispose);

    await _pumpHomeVault(tester, store);

    final warrantyButton = find.byKey(
      const ValueKey('dashboardActiveWarrantyMetric'),
    );

    expect(warrantyButton, findsOneWidget);

    await tester.ensureVisible(warrantyButton);
    await tester.pumpAndSettle();

    await tester.tap(warrantyButton);
    await tester.pumpAndSettle();

    expect(find.text('Warranty center'), findsOneWidget);

    final warrantyList = find.byKey(const Key('warrantyCenterList'));

    expect(warrantyList, findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Family room AC'),
      warrantyList,
      const Offset(0, -350),
      maxIteration: 15,
    );

    await tester.pumpAndSettle();

    expect(find.text('Family room AC'), findsOneWidget);
    expect(find.textContaining('Daikin Care'), findsOneWidget);
    expect(find.textContaining('30 days before expiry'), findsOneWidget);
  });

  testWidgets('service center shows saved maintenance history', (tester) async {
    final appliance = Appliance(
      id: 'ac-service-widget',
      name: 'Family room AC',
      category: 'Air Conditioner',
      brand: 'Daikin',
      serviceRecords: [
        ServiceRecord(
          id: 'service-widget-1',
          serviceDate: DateTime(2026, 8, 2),
          createdAt: DateTime(2026, 8, 2),
          provider: 'Cool Care',
          ticketNumber: 'SR-200',
          problemDescription: 'Cooling reduced',
          workCompleted: 'Coil cleaned',
          serviceCharge: 1200,
          nextServiceDate: DateTime(2027, 2, 2),
          status: ServiceStatus.completed,
          reminderEnabled: true,
        ),
      ],
      createdAt: DateTime(2026, 8, 1),
    );
    final store = await _createStore(initialAppliances: [appliance]);
    addTearDown(store.dispose);

    await _pumpHomeVault(tester, store);

    final serviceButton = find.text('Service center').first;
    await tester.ensureVisible(serviceButton);
    await tester.tap(serviceButton);
    await tester.pumpAndSettle();

    expect(find.text('Service center'), findsOneWidget);
    expect(find.text('Service records'), findsOneWidget);

    final serviceList = find.byKey(const Key('serviceCenterList'));
    expect(serviceList, findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Completed • SR-200'),
      serviceList,
      const Offset(0, -300),
      maxIteration: 10,
    );
    await tester.pumpAndSettle();

    expect(find.text('Completed • SR-200'), findsOneWidget);
    expect(find.textContaining('Family room AC'), findsOneWidget);
    expect(find.textContaining('Cool Care'), findsOneWidget);
  });

  testWidgets('global search finds service and appliance data', (tester) async {
    final appliance = Appliance(
      id: 'search-ac-1',
      name: 'Searchable family AC',
      category: 'Air Conditioner',
      brand: 'Daikin',
      modelNumber: 'FTKM50',
      serviceRecords: [
        ServiceRecord(
          id: 'search-service-1',
          serviceDate: DateTime(2026, 8, 2),
          createdAt: DateTime(2026, 8, 2),
          provider: 'Cool Care',
          ticketNumber: 'SR-SEARCH-200',
          problemDescription: 'Cooling reduced',
          status: ServiceStatus.completed,
        ),
      ],
      createdAt: DateTime(2026, 8, 1),
    );
    final store = await _createStore(initialAppliances: [appliance]);
    addTearDown(store.dispose);

    await _pumpHomeVault(tester, store);

    await tester.tap(find.byTooltip('Search HomeVault'));
    await tester.pumpAndSettle();

    expect(find.text('Global search'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('globalSearchField')),
      'SR-SEARCH-200',
    );
    await tester.pumpAndSettle();

    expect(find.text('Completed • SR-SEARCH-200'), findsOneWidget);
    expect(find.textContaining('Searchable family AC'), findsOneWidget);
    expect(find.text('Service'), findsOneWidget);
  });

  testWidgets('reports screen shows current portfolio insights', (
    tester,
  ) async {
    final appliance = Appliance(
      id: 'report-ac-1',
      name: 'Report AC',
      category: 'Air Conditioner',
      brand: 'Daikin',
      warrantyExpiryDate: DateTime(2026, 8, 20),
      supportProvider: 'Daikin Care',
      additionalDocuments: [
        StoredDocument(
          id: 'report-document-1',
          type: DocumentType.invoice,
          title: 'Report invoice',
          fileName: 'invoice.pdf',
          localPath: '/documents/invoice.pdf',
          sizeBytes: 1000,
          attachedAt: DateTime(2026, 8, 1),
        ),
      ],
      serviceRecords: [
        ServiceRecord(
          id: 'report-service-1',
          serviceDate: DateTime(2026, 8, 2),
          createdAt: DateTime(2026, 8, 2),
          serviceCharge: 1200,
          status: ServiceStatus.completed,
        ),
      ],
      createdAt: DateTime(2026, 8, 1),
    );
    final store = await _createStore(initialAppliances: [appliance]);
    addTearDown(store.dispose);

    await _pumpHomeVault(tester, store);

    await tester.tap(find.byTooltip('Reports and insights'));
    await tester.pumpAndSettle();

    expect(find.text('Reports & insights'), findsOneWidget);
    expect(find.text('Portfolio overview'), findsOneWidget);
    expect(find.text('Service cost'), findsOneWidget);
    expect(find.text('1,200'), findsOneWidget);
  });
}
