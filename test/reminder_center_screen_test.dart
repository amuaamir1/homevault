import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/service_record.dart';
import 'package:homevault/screens/reminders/reminder_center_screen.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/services/reminder_notification_gateway.dart';
import 'package:homevault/state/app_scope.dart';
import 'package:homevault/state/appliance_store.dart';

class _FakeReminderNotificationGateway implements ReminderNotificationGateway {
  _FakeReminderNotificationGateway({
    required this.enabled,
    this.pendingCount = 0,
    this.permissionResult = true,
  });

  bool? enabled;
  int pendingCount;
  bool permissionResult;
  int permissionRequests = 0;
  int testNotifications = 0;

  @override
  Future<bool?> notificationsEnabled() async => enabled;

  @override
  Future<int> pendingReminderCount() async => pendingCount;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    enabled = permissionResult;
    return permissionResult;
  }

  @override
  Future<void> showTestNotification({Appliance? appliance}) async {
    testNotifications++;
  }
}

Future<ApplianceStore> _pumpReminderCenter(
  WidgetTester tester, {
  required List<Appliance> appliances,
  required _FakeReminderNotificationGateway gateway,
  Future<void> Function(String applianceId)? onOpenAppliance,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final store = ApplianceStore(
    repository: MemoryApplianceRepository(initialAppliances: appliances),
  );
  await store.initialize();
  addTearDown(store.dispose);

  await tester.pumpWidget(
    AppScope(
      applianceStore: store,
      child: MaterialApp(
        home: ReminderCenterScreen(
          now: DateTime(2026, 8, 23, 12),
          notificationGateway: gateway,
          onOpenAppliance: onOpenAppliance,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('shows unified reminder types and notification status', (
    tester,
  ) async {
    final gateway = _FakeReminderNotificationGateway(
      enabled: true,
      pendingCount: 2,
    );
    String? openedApplianceId;

    await _pumpReminderCenter(
      tester,
      gateway: gateway,
      onOpenAppliance: (id) async {
        openedApplianceId = id;
      },
      appliances: [
        Appliance(
          id: 'ac',
          name: 'Bedroom AC',
          category: 'Air Conditioner',
          brand: 'Daikin',
          warrantyExpiryDate: DateTime(2026, 9, 2),
          warrantyReminderEnabled: true,
          warrantyReminderDaysBefore: 30,
          createdAt: DateTime(2026, 1, 1),
        ),
        Appliance(
          id: 'purifier',
          name: 'Water purifier',
          category: 'Water Purifier',
          brand: 'Kent',
          amcExpiryDate: DateTime(2026, 10, 22),
          amcReminderEnabled: false,
          createdAt: DateTime(2026, 1, 1),
        ),
        Appliance(
          id: 'washer',
          name: 'Washing machine',
          category: 'Washing Machine',
          brand: 'LG',
          serviceRecords: [
            ServiceRecord(
              id: 'service',
              serviceDate: DateTime(2026, 2, 21),
              createdAt: DateTime(2026, 2, 21),
              nextServiceDate: DateTime(2026, 8, 25),
              status: ServiceStatus.completed,
              reminderEnabled: true,
              reminderDaysBefore: 7,
            ),
          ],
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    expect(find.text('Reminder center'), findsOneWidget);
    expect(find.text('Notifications enabled'), findsOneWidget);
    expect(
      find.textContaining('2 local reminders are currently scheduled.'),
      findsOneWidget,
    );
    expect(find.text('Bedroom AC'), findsOneWidget);
    expect(find.text('Water purifier'), findsOneWidget);
    expect(find.text('Washing machine'), findsOneWidget);
    expect(find.textContaining('Warranty •'), findsOneWidget);
    expect(find.textContaining('AMC •'), findsOneWidget);
    expect(find.textContaining('Maintenance •'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reminderFilter_amc')));
    await tester.pumpAndSettle();

    expect(find.text('Water purifier'), findsOneWidget);
    expect(find.text('Bedroom AC'), findsNothing);
    expect(find.text('Washing machine'), findsNothing);

    final amcCard = find.byKey(const ValueKey('reminderCard_amc|purifier'));
    final amcInkWell = find.descendant(
      of: amcCard,
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(amcInkWell).onTap?.call();
    await tester.pump();
    expect(openedApplianceId, 'purifier');
  });

  testWidgets('can request notification permission from the center', (
    tester,
  ) async {
    final gateway = _FakeReminderNotificationGateway(
      enabled: false,
      permissionResult: true,
    );

    await _pumpReminderCenter(
      tester,
      gateway: gateway,
      appliances: [
        Appliance(
          id: 'ac',
          name: 'Bedroom AC',
          category: 'Air Conditioner',
          brand: 'Daikin',
          warrantyExpiryDate: DateTime(2026, 9, 2),
          warrantyReminderEnabled: true,
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    expect(find.text('Notifications are off'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('enableReminderNotificationsButton')),
    );
    await tester.pumpAndSettle();

    expect(gateway.permissionRequests, 1);
    expect(find.text('Notifications enabled'), findsOneWidget);
    expect(find.text('Reminder notifications are enabled.'), findsOneWidget);
  });
}
