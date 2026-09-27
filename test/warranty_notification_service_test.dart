import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/service_record.dart';
import 'package:homevault/services/warranty_notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

class _ScheduledNotification {
  const _ScheduledNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.payload,
  });

  final int id;
  final String title;
  final String body;
  final tz.TZDateTime date;
  final String payload;
}

class _FakeNotificationPlatform implements WarrantyNotificationPlatform {
  final List<String> events = [];
  final List<int> cancelled = [];
  final List<_ScheduledNotification> scheduled = [];
  final List<WarrantyPendingNotification> pending = [];

  bool failNextCancel = false;
  Completer<void>? cancelGate;
  ValueChanged<String?>? onNotificationResponse;

  @override
  Future<void> cancel(int id) async {
    events.add('cancel-start:$id');
    if (failNextCancel) {
      failNextCancel = false;
      events.add('cancel-failed:$id');
      throw StateError('cancel failed');
    }
    final gate = cancelGate;
    cancelGate = null;
    if (gate != null) await gate.future;
    cancelled.add(id);
    pending.removeWhere((item) => item.id == id);
    events.add('cancel-end:$id');
  }

  @override
  Future<void> cancelAll() async {
    events.add('cancel-all');
    pending.clear();
  }

  @override
  Future<void> initialize({
    required ValueChanged<String?> onNotificationResponse,
  }) async {
    this.onNotificationResponse = onNotificationResponse;
  }

  @override
  Future<String?> launchPayload() async => null;

  @override
  Future<bool?> notificationsEnabled() async => true;

  @override
  Future<List<WarrantyPendingNotification>> pendingNotifications() async =>
      List.of(pending);

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required String payload,
  }) async {
    events.add('schedule:$id');
    scheduled.add(
      _ScheduledNotification(
        id: id,
        title: title,
        body: body,
        date: scheduledDate,
        payload: payload,
      ),
    );
    pending.add(WarrantyPendingNotification(id: id, payload: payload));
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required NotificationDetails notificationDetails,
    String? payload,
  }) async {}
}

Appliance _appliance({
  String id = 'appliance-1',
  DateTime? warrantyExpiry,
  DateTime? extendedExpiry,
  bool enabled = true,
  bool markedExpired = false,
  List<ServiceRecord> serviceRecords = const [],
  DateTime? amcExpiry,
  bool amcEnabled = false,
}) {
  return Appliance(
    id: id,
    name: 'Kitchen fridge',
    category: 'Refrigerator',
    brand: 'LG',
    warrantyExpiryDate: warrantyExpiry ?? DateTime(2026, 10, 30),
    extendedWarrantyExpiryDate: extendedExpiry,
    warrantyReminderEnabled: enabled,
    warrantyMarkedExpired: markedExpired,
    amcExpiryDate: amcExpiry,
    amcReminderEnabled: amcEnabled,
    serviceRecords: serviceRecords,
    createdAt: DateTime(2026, 1, 1),
  );
}

WarrantyNotificationService _service(
  _FakeNotificationPlatform platform,
  DateTime now, {
  String location = 'Etc/UTC',
}) {
  return WarrantyNotificationService(
    platform: platform,
    localLocation: () async => tz.getLocation(location),
    now: () => now,
  );
}

void main() {
  test('milestone IDs are stable, distinct, and reject unsupported values', () {
    final legacy = WarrantyNotificationService.notificationIdFor('a');
    final thirty = WarrantyNotificationService.warrantyNotificationIdFor(
      'a',
      30,
    );
    final seven = WarrantyNotificationService.warrantyNotificationIdFor('a', 7);
    final other = WarrantyNotificationService.warrantyNotificationIdFor(
      'b',
      30,
    );
    final amc = WarrantyNotificationService.amcNotificationIdFor('a');
    final maintenance = WarrantyNotificationService.serviceNotificationIdFor(
      'a',
      'service-1',
    );

    expect({legacy, thirty, seven, other, amc, maintenance}, hasLength(6));
    expect(
      WarrantyNotificationService.warrantyNotificationIdFor('a', 30),
      thirty,
    );
    expect(
      () => WarrantyNotificationService.warrantyNotificationIdFor('a', 14),
      throwsArgumentError,
    );
  });

  test('structured warranty payload round-trips and validates every field', () {
    final payload = const WarrantyNotificationPayload(
      applianceId: 'appliance-1',
      milestoneDays: 30,
    ).encode();
    final parsed = WarrantyNotificationPayload.tryParse(payload);

    expect(
      payload,
      '{"version":1,"type":"warranty","applianceId":"appliance-1","milestoneDays":30}',
    );
    expect(parsed?.applianceId, 'appliance-1');
    expect(parsed?.milestoneDays, 30);
    expect(
      WarrantyNotificationService.applianceIdFromPayload(payload),
      'appliance-1',
    );

    for (final malformed in [
      '',
      '{',
      '[]',
      '{"version":2,"type":"warranty","applianceId":"a","milestoneDays":30}',
      '{"version":1,"type":"amc","applianceId":"a","milestoneDays":30}',
      '{"version":1,"type":"warranty","applianceId":"","milestoneDays":30}',
      '{"version":1,"type":"warranty","applianceId":"a","milestoneDays":14}',
    ]) {
      expect(WarrantyNotificationPayload.tryParse(malformed), isNull);
      expect(
        WarrantyNotificationService.applianceIdFromPayload(malformed),
        isNull,
      );
    }
  });

  test('legacy warranty, AMC, and service payloads remain accepted', () {
    expect(
      WarrantyNotificationService.applianceIdFromPayload('appliance-1'),
      'appliance-1',
    );
    expect(
      WarrantyNotificationService.applianceIdFromPayload('amc|appliance-1'),
      'appliance-1',
    );
    expect(
      WarrantyNotificationService.applianceIdFromPayload(
        'service|appliance-1|service-1',
      ),
      'appliance-1',
    );
    expect(
      WarrantyNotificationService.applianceIdFromPayload('service|missing'),
      isNull,
    );
  });

  test(
    'schedules two eligible reminders with approved copy and payloads',
    () async {
      final platform = _FakeNotificationPlatform();
      final service = _service(platform, DateTime.utc(2026, 9, 1));

      await service.scheduleFor(_appliance());

      expect(platform.scheduled, hasLength(2));
      expect(platform.scheduled.map((item) => item.date.day), [30, 23]);
      expect(platform.scheduled.map((item) => item.date.hour), everyElement(9));
      expect(
        platform.scheduled.first.title,
        'Kitchen fridge: 30-day warranty reminder',
      );
      expect(
        platform.scheduled.first.body,
        'Effective warranty expires on 30/10/2026. Review coverage and plan any needed service or claim.',
      );
      expect(
        platform.scheduled.last.body,
        'Effective warranty expires on 30/10/2026. Act now on any needed service or warranty claim.',
      );
      expect(
        WarrantyNotificationPayload.tryParse(
          platform.scheduled.first.payload,
        )?.milestoneDays,
        30,
      );
    },
  );

  test('uses later effective extended expiry for both reminders', () async {
    final platform = _FakeNotificationPlatform();
    final service = _service(platform, DateTime.utc(2026, 9, 1));

    await service.scheduleFor(
      _appliance(
        warrantyExpiry: DateTime(2026, 10, 30),
        extendedExpiry: DateTime(2027, 2, 15),
      ),
    );

    expect(platform.scheduled.map((item) => item.date.day), [16, 8]);
    expect(platform.scheduled.map((item) => item.date.month), [1, 2]);
    expect(platform.scheduled.first.body, contains('15/02/2027'));
  });

  test('strict 09:00 boundary yields two, one, or zero reminders', () async {
    Future<int> countAt(DateTime instant) async {
      final platform = _FakeNotificationPlatform();
      await _service(platform, instant).scheduleFor(_appliance());
      return platform.scheduled.length;
    }

    expect(await countAt(DateTime.utc(2026, 9, 30, 8, 59, 59)), 2);
    expect(await countAt(DateTime.utc(2026, 9, 30, 9)), 1);
    expect(await countAt(DateTime.utc(2026, 9, 30, 9, 0, 1)), 1);
    expect(await countAt(DateTime.utc(2026, 10, 23, 9)), 0);
    expect(await countAt(DateTime.utc(2026, 10, 29, 12)), 0);
  });

  test('opt-out and manual expiry cancel IDs and schedule nothing', () async {
    for (final appliance in [
      _appliance(enabled: false),
      _appliance(markedExpired: true),
      Appliance(
        id: 'appliance-1',
        name: 'No expiry',
        category: 'Other',
        brand: '',
        warrantyReminderEnabled: true,
        createdAt: DateTime(2026, 1, 1),
      ),
    ]) {
      final platform = _FakeNotificationPlatform();
      await _service(platform, DateTime.utc(2026, 9, 1)).scheduleFor(appliance);
      expect(platform.scheduled, isEmpty);
      expect(platform.cancelled.take(3), [
        WarrantyNotificationService.warrantyNotificationIdFor(appliance.id, 30),
        WarrantyNotificationService.warrantyNotificationIdFor(appliance.id, 7),
        WarrantyNotificationService.notificationIdFor(appliance.id),
      ]);
    }
  });

  test('cancels milestone and legacy IDs before expiry rescheduling', () async {
    final platform = _FakeNotificationPlatform();
    final service = _service(platform, DateTime.utc(2026, 9, 1));

    await service.scheduleFor(_appliance());
    final firstScheduleIndex = platform.events.indexWhere(
      (event) => event.startsWith('schedule:'),
    );
    expect(firstScheduleIndex, greaterThanOrEqualTo(6));
    expect(platform.cancelled.take(3), [
      WarrantyNotificationService.warrantyNotificationIdFor('appliance-1', 30),
      WarrantyNotificationService.warrantyNotificationIdFor('appliance-1', 7),
      WarrantyNotificationService.notificationIdFor('appliance-1'),
    ]);

    platform.events.clear();
    platform.scheduled.clear();
    await service.scheduleFor(
      _appliance(warrantyExpiry: DateTime(2026, 12, 1)),
    );
    expect(platform.events.take(6), everyElement(startsWith('cancel')));
    expect(platform.scheduled.map((item) => item.date.month), [11, 11]);
    expect(platform.scheduled.map((item) => item.date.day), [1, 24]);
  });

  test('appliance cancellation does not remove another appliance', () async {
    final platform = _FakeNotificationPlatform();
    final otherPayload = const WarrantyNotificationPayload(
      applianceId: 'other',
      milestoneDays: 30,
    ).encode();
    platform.pending.addAll([
      WarrantyPendingNotification(id: 100, payload: 'appliance-1'),
      WarrantyPendingNotification(id: 200, payload: otherPayload),
    ]);

    await _service(platform, DateTime.utc(2026, 9, 1)).cancelFor('appliance-1');

    expect(platform.cancelled, contains(100));
    expect(platform.cancelled, isNot(contains(200)));
    expect(platform.pending.single.id, 200);
  });

  test('notification mutations are FIFO when operations overlap', () async {
    final platform = _FakeNotificationPlatform();
    final gate = Completer<void>();
    platform.cancelGate = gate;
    final service = _service(platform, DateTime.utc(2026, 9, 1));

    final first = service.scheduleFor(_appliance(id: 'first'));
    await Future<void>.delayed(Duration.zero);
    final second = service.cancelFor('second');
    await Future<void>.delayed(Duration.zero);

    expect(platform.events, hasLength(1));
    gate.complete();
    await Future.wait([first, second]);

    final firstSchedule = platform.events.indexWhere(
      (event) =>
          event ==
          'schedule:${WarrantyNotificationService.warrantyNotificationIdFor('first', 30)}',
    );
    final secondCancel = platform.events.indexWhere(
      (event) =>
          event ==
          'cancel-start:${WarrantyNotificationService.warrantyNotificationIdFor('second', 30)}',
    );
    expect(firstSchedule, lessThan(secondCancel));
  });

  test('a failed queued mutation does not poison the queue', () async {
    final platform = _FakeNotificationPlatform()..failNextCancel = true;
    final service = _service(platform, DateTime.utc(2026, 9, 1));

    await expectLater(service.cancelFor('first'), throwsStateError);
    await service.scheduleFor(_appliance(id: 'second'));

    expect(platform.scheduled, hasLength(2));
    expect(
      WarrantyNotificationPayload.tryParse(
        platform.scheduled.first.payload,
      )?.applianceId,
      'second',
    );
  });

  test('AMC and maintenance scheduling behavior remains available', () async {
    final platform = _FakeNotificationPlatform();
    final record = ServiceRecord(
      id: 'service-1',
      serviceDate: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      nextServiceDate: DateTime(2026, 10, 15),
      reminderEnabled: true,
      reminderDaysBefore: 7,
      status: ServiceStatus.completed,
    );
    await _service(platform, DateTime.utc(2026, 9, 1)).scheduleFor(
      _appliance(
        enabled: false,
        amcExpiry: DateTime(2026, 11, 1),
        amcEnabled: true,
        serviceRecords: [record],
      ),
    );

    expect(platform.scheduled, hasLength(2));
    expect(platform.scheduled.map((item) => item.payload), [
      'amc|appliance-1',
      'service|appliance-1|service-1',
    ]);
  });
}
