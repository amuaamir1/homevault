import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/appliance.dart';
import '../models/service_record.dart';

abstract class WarrantyReminderScheduler {
  Future<void> syncAll(List<Appliance> appliances);

  Future<void> scheduleFor(Appliance appliance);

  Future<void> cancelFor(String applianceId);
}

class NoOpWarrantyReminderScheduler implements WarrantyReminderScheduler {
  const NoOpWarrantyReminderScheduler();

  @override
  Future<void> cancelFor(String applianceId) async {}

  @override
  Future<void> scheduleFor(Appliance appliance) async {}

  @override
  Future<void> syncAll(List<Appliance> appliances) async {}
}

class WarrantyNotificationService implements WarrantyReminderScheduler {
  WarrantyNotificationService._();

  static final WarrantyNotificationService instance =
      WarrantyNotificationService._();

  static const _warrantyChannelId = 'warranty_reminders';
  static const _warrantyChannelName = 'Warranty reminders';
  static const _warrantyChannelDescription =
      'Alerts before appliance warranties expire.';

  static const _serviceChannelId = 'service_reminders';
  static const _serviceChannelName = 'Maintenance reminders';
  static const _serviceChannelDescription =
      'Alerts before scheduled appliance maintenance.';

  static const _servicePayloadPrefix = 'service|';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<String> _notificationTapController =
      StreamController<String>.broadcast();

  bool _initialized = false;
  String? _pendingPayload;

  Stream<String> get notificationTaps => _notificationTapController.stream;

  String? takePendingApplianceId() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    return _applianceIdFromPayload(payload);
  }

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload?.trim();
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      _pendingPayload = launchPayload;
    }

    _initialized = true;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final applianceId = _applianceIdFromPayload(response.payload);
    if (applianceId == null) return;

    if (_notificationTapController.hasListener) {
      _notificationTapController.add(applianceId);
    } else {
      _pendingPayload = response.payload;
    }
  }

  Future<bool> requestPermission() async {
    await initialize();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidPlugin?.requestNotificationsPermission() ?? true;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  Future<bool?> notificationsEnabled() async {
    await initialize();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return androidPlugin?.areNotificationsEnabled();
    }

    return null;
  }

  Future<int> pendingReminderCount() async {
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    return pending
        .where((request) => request.payload?.isNotEmpty == true)
        .length;
  }

  Future<void> showTestNotification({Appliance? appliance}) async {
    await initialize();
    await _plugin.show(
      id: 2147483000,
      title: 'HomeVault reminder test',
      body: appliance == null
          ? 'Notifications are working on this device.'
          : 'Test reminder for ${appliance.name}.',
      notificationDetails: _warrantyNotificationDetails,
      payload: appliance?.id,
    );
  }

  @override
  Future<void> syncAll(List<Appliance> appliances) async {
    await initialize();
    await _plugin.cancelAll();

    for (final appliance in appliances) {
      await _scheduleCurrentReminders(appliance);
    }
  }

  @override
  Future<void> scheduleFor(Appliance appliance) async {
    await initialize();
    await cancelFor(appliance.id);
    await _scheduleCurrentReminders(appliance);
  }

  Future<void> _scheduleCurrentReminders(Appliance appliance) async {
    await _scheduleWarrantyReminder(appliance);
    for (final record in appliance.serviceRecords) {
      await _scheduleServiceReminder(appliance, record);
    }
  }

  Future<void> _scheduleWarrantyReminder(Appliance appliance) async {
    final reminderDate = appliance.warrantyReminderDateAt();
    final expiryDate = appliance.effectiveWarrantyExpiryDate;
    if (reminderDate == null || expiryDate == null) return;

    final scheduledDate = tz.TZDateTime.from(reminderDate, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (!scheduledDate.isAfter(now)) return;

    await _plugin.zonedSchedule(
      id: notificationIdFor(appliance.id),
      title: '${appliance.name} warranty expires soon',
      body: _warrantyNotificationBody(appliance, expiryDate),
      scheduledDate: scheduledDate,
      notificationDetails: _warrantyNotificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: appliance.id,
    );
  }

  Future<void> _scheduleServiceReminder(
    Appliance appliance,
    ServiceRecord record,
  ) async {
    final reminderDate = record.reminderDateAt();
    final nextServiceDate = record.nextServiceDate;
    if (reminderDate == null || nextServiceDate == null) return;

    final scheduledDate = tz.TZDateTime.from(reminderDate, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (!scheduledDate.isAfter(now)) return;

    await _plugin.zonedSchedule(
      id: serviceNotificationIdFor(appliance.id, record.id),
      title: '${appliance.name} service is due soon',
      body: _serviceNotificationBody(record, nextServiceDate),
      scheduledDate: scheduledDate,
      notificationDetails: _serviceNotificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '$_servicePayloadPrefix${appliance.id}|${record.id}',
    );
  }

  @override
  Future<void> cancelFor(String applianceId) async {
    await initialize();
    await _plugin.cancel(id: notificationIdFor(applianceId));

    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (_applianceIdFromPayload(request.payload) == applianceId) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  static const NotificationDetails _warrantyNotificationDetails =
      NotificationDetails(
        android: AndroidNotificationDetails(
          _warrantyChannelId,
          _warrantyChannelName,
          channelDescription: _warrantyChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  static const NotificationDetails _serviceNotificationDetails =
      NotificationDetails(
        android: AndroidNotificationDetails(
          _serviceChannelId,
          _serviceChannelName,
          channelDescription: _serviceChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  static int notificationIdFor(String applianceId) {
    return _stableNotificationId('warranty|$applianceId');
  }

  static int serviceNotificationIdFor(
    String applianceId,
    String serviceRecordId,
  ) {
    return _stableNotificationId('service|$applianceId|$serviceRecordId');
  }

  static int _stableNotificationId(String input) {
    var hash = 0x811C9DC5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  static String _warrantyNotificationBody(
    Appliance appliance,
    DateTime expiryDate,
  ) {
    final provider = appliance.warrantyProvider.trim();
    final providerText = provider.isEmpty ? '' : ' with $provider';
    return 'Warranty$providerText expires on ${_date(expiryDate)}.';
  }

  static String _serviceNotificationBody(
    ServiceRecord record,
    DateTime nextServiceDate,
  ) {
    final provider = record.provider.trim();
    final providerText = provider.isEmpty ? '' : ' with $provider';
    return 'Maintenance$providerText is scheduled for ${_date(nextServiceDate)}.';
  }

  static String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static String? _applianceIdFromPayload(String? payload) {
    final value = payload?.trim();
    if (value == null || value.isEmpty) return null;
    if (!value.startsWith(_servicePayloadPrefix)) return value;

    final parts = value.split('|');
    if (parts.length < 3 || parts[1].trim().isEmpty) return null;
    return parts[1].trim();
  }
}
