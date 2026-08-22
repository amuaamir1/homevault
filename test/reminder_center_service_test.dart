import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/homevault_reminder.dart';
import 'package:homevault/models/service_record.dart';
import 'package:homevault/services/reminder_center_service.dart';

void main() {
  const service = ReminderCenterService();
  final now = DateTime(2026, 8, 23, 12);

  test('builds one unified timeline for warranty AMC and maintenance', () {
    final appliances = [
      Appliance(
        id: 'ac',
        name: 'Bedroom AC',
        category: 'Air Conditioner',
        brand: 'Daikin',
        warrantyExpiryDate: DateTime(2026, 9, 2),
        warrantyProvider: 'Daikin Care',
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
        amcProvider: 'Kent Service',
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
            id: 'service-1',
            serviceDate: DateTime(2026, 2, 21),
            createdAt: DateTime(2026, 2, 21),
            provider: 'LG Service',
            nextServiceDate: DateTime(2026, 8, 21),
            status: ServiceStatus.completed,
            reminderEnabled: true,
            reminderDaysBefore: 7,
          ),
        ],
        createdAt: DateTime(2026, 1, 1),
      ),
    ];

    final reminders = service.build(appliances, now: now);

    expect(reminders, hasLength(3));
    expect(reminders[0].type, HomeVaultReminderType.maintenance);
    expect(reminders[0].daysUntilDueAt(now), -2);
    expect(reminders[1].type, HomeVaultReminderType.warranty);
    expect(reminders[1].daysUntilDueAt(now), 10);
    expect(reminders[2].type, HomeVaultReminderType.amc);
    expect(reminders[2].daysUntilDueAt(now), 60);

    final summary = service.summarize(reminders, now: now);
    expect(summary.total, 3);
    expect(summary.attention, 2);
    expect(summary.overdue, 1);
    expect(summary.next30Days, 1);
    expect(summary.notificationsOn, 2);
    expect(summary.notificationsOff, 1);
  });

  test('effective extended warranty uses the extended provider', () {
    final appliance = Appliance(
      id: 'tv',
      name: 'TV',
      category: 'Television',
      brand: 'Samsung',
      warrantyExpiryDate: DateTime(2026, 9, 1),
      warrantyProvider: 'Samsung',
      extendedWarrantyExpiryDate: DateTime(2027, 1, 1),
      extendedWarrantyProvider: 'Retail Protect',
      createdAt: DateTime(2026, 1, 1),
    );

    final reminder = service.build([appliance], now: now).single;

    expect(reminder.type, HomeVaultReminderType.warranty);
    expect(reminder.dueDate, DateTime(2027, 1, 1));
    expect(reminder.provider, 'Retail Protect');
  });

  test('manually ended warranty does not create a future reminder entry', () {
    final appliance = Appliance(
      id: 'fridge',
      name: 'Fridge',
      category: 'Refrigerator',
      brand: 'LG',
      warrantyExpiryDate: DateTime(2027, 1, 1),
      warrantyMarkedExpired: true,
      warrantyReminderEnabled: true,
      createdAt: DateTime(2026, 1, 1),
    );

    expect(service.build([appliance], now: now), isEmpty);
  });

  test('attention window includes only recent overdue and next 30 days', () {
    final recentOverdue = HomeVaultReminder(
      id: 'recent',
      type: HomeVaultReminderType.warranty,
      applianceId: 'a',
      applianceName: 'A',
      dueDate: DateTime(2026, 8, 20),
      notificationEnabled: false,
      reminderDaysBefore: 30,
    );
    final oldOverdue = HomeVaultReminder(
      id: 'old',
      type: HomeVaultReminderType.warranty,
      applianceId: 'b',
      applianceName: 'B',
      dueDate: DateTime(2026, 6, 1),
      notificationEnabled: false,
      reminderDaysBefore: 30,
    );
    final future = HomeVaultReminder(
      id: 'future',
      type: HomeVaultReminderType.amc,
      applianceId: 'c',
      applianceName: 'C',
      dueDate: DateTime(2026, 9, 10),
      notificationEnabled: true,
      reminderDaysBefore: 14,
    );

    expect(recentOverdue.needsAttentionAt(now), isTrue);
    expect(oldOverdue.needsAttentionAt(now), isFalse);
    expect(future.needsAttentionAt(now), isTrue);
  });
}
