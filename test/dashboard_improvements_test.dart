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

Future<void> _pumpDashboard(
  WidgetTester tester,
  List<Appliance> appliances,
) async {
  const uid = 'dashboard-user';
  final store = ApplianceStore(
    repository: MemoryApplianceRepository(initialAppliances: appliances),
  );
  await store.bindOwner(uid);

  final lockController = AppLockController.unlockedForTesting(uid: uid);
  final authController = AuthController.authenticatedForTesting(
    uid: uid,
    phoneNumber: '+919876543210',
  );
  final profileController = ProfileController.loadedForTesting(
    UserProfile(
      uid: uid,
      fullName: 'Aamir Test',
      phoneNumber: '+919876543210',
      addressLine1: '12 Test Street',
      state: 'Delhi',
      city: 'New Delhi',
      pinCode: '110001',
    ),
  );

  addTearDown(store.dispose);
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
  testWidgets('dashboard shows actionable portfolio summary', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final appliances = [
      Appliance(
        id: 'active-tv',
        name: 'Living room TV',
        category: 'Television',
        brand: 'Samsung',
        warrantyExpiryDate: today.add(const Duration(days: 120)),
        supportProvider: 'Samsung Care',
        invoiceDocument: StoredDocument(
          id: 'invoice-tv',
          type: DocumentType.invoice,
          title: 'TV invoice',
          fileName: 'tv-invoice.pdf',
          localPath: '/documents/tv-invoice.pdf',
          sizeBytes: 1200,
          attachedAt: today,
        ),
        createdAt: today,
      ),
      Appliance(
        id: 'expiring-ac',
        name: 'Bedroom AC',
        category: 'Air Conditioner',
        brand: 'Daikin',
        warrantyExpiryDate: today.add(const Duration(days: 10)),
        serviceRecords: [
          ServiceRecord(
            id: 'service-ac',
            serviceDate: today.subtract(const Duration(days: 180)),
            createdAt: today.subtract(const Duration(days: 180)),
            nextServiceDate: today.add(const Duration(days: 5)),
            status: ServiceStatus.completed,
          ),
        ],
        createdAt: today,
      ),
    ];

    await _pumpDashboard(tester, appliances);

    expect(find.text('At a glance'), findsOneWidget);
    expect(find.text('Warranty overview'), findsOneWidget);
    expect(find.text('Coming up'), findsOneWidget);
    expect(find.text('Record completeness'), findsNothing);
    expect(find.text('Quick actions'), findsNothing);
    expect(
      find.byKey(const ValueKey('dashboardNoStretchScrollConfiguration')),
      findsOneWidget,
    );

    final applianceMetric = find.byKey(
      const ValueKey('dashboardApplianceMetric'),
    );
    expect(applianceMetric, findsOneWidget);
    expect(
      find.descendant(of: applianceMetric, matching: find.text('2')),
      findsOneWidget,
    );

    final activeMetric = find.byKey(
      const ValueKey('dashboardActiveWarrantyMetric'),
    );
    expect(
      find.descendant(of: activeMetric, matching: find.text('1')),
      findsOneWidget,
    );

    expect(find.text('Bedroom AC'), findsWidgets);
    expect(find.text('Warranty expires in 10 days'), findsOneWidget);
    expect(find.text('Service due in 5 days'), findsOneWidget);

    expect(find.byTooltip('Reminder center'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dashboardReminderBadge')),
      findsOneWidget,
    );
  });
}
