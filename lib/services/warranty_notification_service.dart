import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/appliance.dart';

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

  static const _channelId = 'warranty_reminders';
  static const _channelName = 'Warranty reminders';
  static const _channelDescription =
      'Alerts before appliance warranties expire.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<String> _notificationTapController =
      StreamController<String>.broadcast();

  bool _initialized = false;
  String? _pendingApplianceId;

  Stream<String> get notificationTaps => _notificationTapController.stream;

  String? takePendingApplianceId() {
    final applianceId = _pendingApplianceId;
    _pendingApplianceId = null;
    return applianceId;
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
      _pendingApplianceId = launchPayload;
    }

    _initialized = true;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final applianceId = response.payload?.trim();
    if (applianceId == null || applianceId.isEmpty) {
      return;
    }

    if (_notificationTapController.hasListener) {
      _notificationTapController.add(applianceId);
    } else {
      _pendingApplianceId = applianceId;
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
    return pending.length;
  }

  Future<void> showTestNotification({Appliance? appliance}) async {
    await initialize();
    await _plugin.show(
      id: 2147483000,
      title: 'HomeVault warranty reminder',
      body: appliance == null
          ? 'Notifications are working on this device.'
          : 'Test reminder for ${appliance.name}.',
      notificationDetails: _notificationDetails,
      payload: appliance?.id,
    );
  }

  @override
  Future<void> syncAll(List<Appliance> appliances) async {
    await initialize();
    await _plugin.cancelAll();

    for (final appliance in appliances) {
      await scheduleFor(appliance);
    }
  }

  @override
  Future<void> scheduleFor(Appliance appliance) async {
    await initialize();
    await cancelFor(appliance.id);

    final reminderDate = appliance.warrantyReminderDateAt();
    final expiryDate = appliance.effectiveWarrantyExpiryDate;
    if (reminderDate == null || expiryDate == null) {
      return;
    }

    final scheduledDate = tz.TZDateTime.from(reminderDate, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (!scheduledDate.isAfter(now)) {
      return;
    }

    await _plugin.zonedSchedule(
      id: notificationIdFor(appliance.id),
      title: '${appliance.name} warranty expires soon',
      body: _notificationBody(appliance, expiryDate),
      scheduledDate: scheduledDate,
      notificationDetails: _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: appliance.id,
    );
  }

  @override
  Future<void> cancelFor(String applianceId) async {
    await initialize();
    await _plugin.cancel(id: notificationIdFor(applianceId));
  }

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static int notificationIdFor(String applianceId) {
    var hash = 0x811C9DC5;
    for (final codeUnit in applianceId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  static String _notificationBody(Appliance appliance, DateTime expiryDate) {
    final day = expiryDate.day.toString().padLeft(2, '0');
    final month = expiryDate.month.toString().padLeft(2, '0');
    final provider = appliance.warrantyProvider.trim();
    final providerText = provider.isEmpty ? '' : ' with $provider';
    return 'Warranty$providerText expires on $day/$month/${expiryDate.year}.';
  }
}
