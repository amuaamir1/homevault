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

Future<void> _pumpHomeVault(
  WidgetTester tester,
  ApplianceStore store, {
  bool isEmailVerified = true,
}) async {
  const testUid = 'test-user';

  // Bind the test database before building the app so the startup gate
  // does not remain on an animated loading screen.
  await store.bindOwner(testUid);

  final lockController = AppLockController.unlockedForTesting(uid: testUid);

  final authController = AuthController.authenticatedForTesting(
    uid: testUid,
    phoneNumber: '+919876543210',
    isEmailVerified: isEmailVerified,
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
    expect(find.text('Quick actions'), findsNothing);

    final navigationBar = find.byType(NavigationBar);
    expect(navigationBar, findsOneWidget);
    expect(
      find.descendant(of: navigationBar, matching: find.text('Home')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigationBar, matching: find.text('Service center')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigationBar, matching: find.text('Support')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigationBar, matching: find.text('Settings')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigationBar, matching: find.text('Appliances')),
      findsNothing,
    );
    expect(
      find.descendant(of: navigationBar, matching: find.text('Documents')),
      findsNothing,
    );
  });

  testWidgets('unverified email user can continue into HomeVault', (
    tester,
  ) async {
    final store = await _createStore();
    addTearDown(store.dispose);

    await _pumpHomeVault(tester, store, isEmailVerified: false);

    expect(find.text('HomeVault'), findsOneWidget);
    expect(find.text('Welcome Aamir'), findsOneWidget);
    expect(find.text('Verify your email'), findsNothing);
  });

  testWidgets('user can open the add appliance form', (tester) async {
    final store = await _createStore();
    addTearDown(store.dispose);

    await _pumpHomeVault(tester, store);

    // The dashboard has more than one 'Add appliance' tooltip (for example,
    // the AppBar action and an in-content action). Scope the finder to the
    // AppBar so this test targets the intended control.
    final addApplianceButton = find.descendant(
      of: find.byType(AppBar),
      matching: find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Add appliance',
      ),
    );
    expect(addApplianceButton, findsOneWidget);

    await tester.ensureVisible(addApplianceButton);
    await tester.pumpAndSettle();
    await tester.tap(addApplianceButton);
    await tester.pumpAndSettle();

    expect(find.text('Appliance details'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Appliance name (required)'),
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

    final documentsMetric = find.byKey(
      const ValueKey('dashboardDocumentMetric'),
    );
    expect(documentsMetric, findsOneWidget);
    await tester.tap(documentsMetric);
    await tester.pumpAndSettle();

    expect(find.text('AC manual'), findsOneWidget);
    expect(find.textContaining('Living room AC'), findsOneWidget);
    expect(find.text('Add document'), findsOneWidget);
  });

  testWidgets('provider directory exposes manufacturer and support contacts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    expect(find.text('Provider directory'), findsOneWidget);
    expect(find.text('Daikin'), findsOneWidget);
    expect(find.text('Daikin Care'), findsOneWidget);
    expect(find.textContaining('Manufacturer'), findsWidgets);

    await tester.tap(find.text('Daikin Care'));
    await tester.pumpAndSettle();

    expect(find.text('Provider details'), findsOneWidget);
    expect(find.text('Customer support'), findsOneWidget);
    expect(find.text('Bedroom AC'), findsOneWidget);
    expect(find.text('Sunday to Thursday'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('Call'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('Email'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('Website'),
      ),
      findsOneWidget,
    );
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

    final serviceDestination = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Service center'),
    );
    expect(serviceDestination, findsOneWidget);
    await tester.tap(serviceDestination);
    await tester.pumpAndSettle();

    // 'Service center' also appears in the bottom navigation label. Verify
    // the screen title specifically instead of matching both widgets.
    final serviceCenterTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Service center'),
    );
    expect(serviceCenterTitle, findsOneWidget);
    expect(find.text('Records'), findsOneWidget);

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

    // Invoke the button callback directly instead of synthesizing a pointer
    // tap. Navigating away disposes several dashboard Tooltip widgets while
    // the test binding is still routing the PointerUpEvent, which can make
    // RawTooltip try to create a second ticker and fail the test even though
    // Reports navigation itself is correct.
    final reportsButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Reports'),
    );
    reportsButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.text('Reports & insights'), findsOneWidget);
    expect(find.text('Portfolio overview'), findsOneWidget);
    expect(find.text('Service cost'), findsOneWidget);
    expect(find.text('1,200'), findsOneWidget);
  });
}
