import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/appliance.dart';
import '../models/service_record.dart';
import 'reminder_schedule_service.dart';

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

class WarrantyPendingNotification {
  const WarrantyPendingNotification({required this.id, this.payload});

  final int id;
  final String? payload;
}

abstract class WarrantyNotificationPlatform {
  Future<void> initialize({
    required ValueChanged<String?> onNotificationResponse,
  });

  Future<String?> launchPayload();

  Future<bool> requestPermission();

  Future<bool?> notificationsEnabled();

  Future<List<WarrantyPendingNotification>> pendingNotifications();

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required NotificationDetails notificationDetails,
    String? payload,
  });

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required String payload,
  });

  Future<void> cancel(int id);

  Future<void> cancelAll();
}

class WarrantyNotificationPayload {
  const WarrantyNotificationPayload({
    required this.applianceId,
    required this.milestoneDays,
  });

  static const version = 1;
  static const type = 'warranty';

  final String applianceId;
  final int milestoneDays;

  String encode() {
    if (applianceId.trim().isEmpty) {
      throw ArgumentError.value(
        applianceId,
        'applianceId',
        'Appliance ID must not be empty.',
      );
    }
    WarrantyReminderMilestone.fromDays(milestoneDays);
    return jsonEncode({
      'version': version,
      'type': type,
      'applianceId': applianceId,
      'milestoneDays': milestoneDays,
    });
  }

  static WarrantyNotificationPayload? tryParse(String? payload) {
    final value = payload?.trim();
    if (value == null || value.isEmpty) return null;

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      if (decoded['version'] != version || decoded['type'] != type) return null;
      final applianceId = decoded['applianceId'];
      final milestoneDays = decoded['milestoneDays'];
      if (applianceId is! String || applianceId.trim().isEmpty) return null;
      if (milestoneDays is! int) return null;
      WarrantyReminderMilestone.fromDays(milestoneDays);
      return WarrantyNotificationPayload(
        applianceId: applianceId.trim(),
        milestoneDays: milestoneDays,
      );
    } catch (_) {
      return null;
    }
  }
}

class WarrantyNotificationService implements WarrantyReminderScheduler {
  WarrantyNotificationService({
    WarrantyNotificationPlatform? platform,
    Future<tz.Location> Function()? localLocation,
    DateTime Function()? now,
  }) : _platform = platform ?? _PluginWarrantyNotificationPlatform(),
       _localLocation = localLocation ?? _resolveDeviceLocation,
       _now = now ?? DateTime.now;

  static final WarrantyNotificationService instance =
      WarrantyNotificationService();

  static const _warrantyChannelId = 'warranty_reminders';
  static const _warrantyChannelName = 'Warranty reminders';
  static const _warrantyChannelDescription =
      'Alerts before appliance warranties expire.';
  static const _serviceChannelId = 'service_reminders';
  static const _serviceChannelName = 'Maintenance reminders';
  static const _serviceChannelDescription =
      'Alerts before scheduled appliance maintenance.';
  static const _servicePayloadPrefix = 'service|';
  static const _amcPayloadPrefix = 'amc|';
  static const _amcChannelId = 'amc_reminders';
  static const _amcChannelName = 'AMC reminders';
  static const _amcChannelDescription =
      'Alerts before appliance annual maintenance contracts expire.';

  final WarrantyNotificationPlatform _platform;
  final Future<tz.Location> Function() _localLocation;
  final DateTime Function() _now;
  final StreamController<String> _notificationTapController =
      StreamController<String>.broadcast();

  Future<void>? _initialization;
  Future<void> _mutationTail = Future<void>.value();
  tz.Location? _location;
  String? _pendingPayload;

  Stream<String> get notificationTaps => _notificationTapController.stream;

  String? takePendingApplianceId() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    return applianceIdFromPayload(payload);
  }

  Future<void> initialize() async {
    final initialization = _initialization ??= _initialize();
    try {
      await initialization;
    } catch (_) {
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
      rethrow;
    }
  }

  Future<void> _initialize() async {
    tz.initializeTimeZones();
    try {
      _location = await _localLocation();
    } catch (_) {
      _location = tz.getLocation('Etc/UTC');
    }

    await _platform.initialize(onNotificationResponse: _handlePayload);
    final launchPayload = (await _platform.launchPayload())?.trim();
    if (launchPayload != null && launchPayload.isNotEmpty) {
      _pendingPayload = launchPayload;
    }
  }

  static Future<tz.Location> _resolveDeviceLocation() async {
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    final location = tz.getLocation(timezoneInfo.identifier);
    tz.setLocalLocation(location);
    return location;
  }

  void _handlePayload(String? payload) {
    final applianceId = applianceIdFromPayload(payload);
    if (applianceId == null) return;
    if (_notificationTapController.hasListener) {
      _notificationTapController.add(applianceId);
    } else {
      _pendingPayload = payload;
    }
  }

  Future<bool> requestPermission() async {
    await initialize();
    return _platform.requestPermission();
  }

  Future<bool?> notificationsEnabled() async {
    await initialize();
    return _platform.notificationsEnabled();
  }

  Future<int> pendingReminderCount() async {
    await initialize();
    final pending = await _platform.pendingNotifications();
    return pending.where((item) => item.payload?.isNotEmpty == true).length;
  }

  Future<void> showTestNotification({Appliance? appliance}) async {
    await initialize();
    await _platform.show(
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
  Future<void> syncAll(List<Appliance> appliances) {
    return _enqueueMutation(() async {
      await initialize();
      await _platform.cancelAll();
      for (final appliance in appliances) {
        await _cancelWarrantyIds(appliance.id);
        await _scheduleCurrentReminders(appliance);
      }
    });
  }

  @override
  Future<void> scheduleFor(Appliance appliance) {
    return _enqueueMutation(() async {
      await initialize();
      await _cancelFor(appliance.id);
      await _scheduleCurrentReminders(appliance);
    });
  }

  @override
  Future<void> cancelFor(String applianceId) {
    return _enqueueMutation(() async {
      await initialize();
      await _cancelFor(applianceId);
    });
  }

  Future<void> _enqueueMutation(Future<void> Function() operation) {
    final result = _mutationTail.then((_) => operation());
    _mutationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _scheduleCurrentReminders(Appliance appliance) async {
    await _scheduleWarrantyReminders(appliance);
    await _scheduleAmcReminder(appliance);
    final maintenanceRecord = appliance.maintenanceScheduleRecord;
    if (maintenanceRecord != null) {
      await _scheduleServiceReminder(appliance, maintenanceRecord);
    }
  }

  Future<void> _scheduleWarrantyReminders(Appliance appliance) async {
    final expiryDate = appliance.effectiveWarrantyExpiryDate;
    if (!appliance.warrantyReminderEnabled ||
        appliance.warrantyMarkedExpired ||
        expiryDate == null) {
      return;
    }

    final currentInstant = _now();
    for (final milestone in WarrantyReminderMilestone.values) {
      final scheduledDate = ReminderScheduleService.eligibleWarrantyCandidate(
        effectiveExpiryDate: expiryDate,
        milestone: milestone,
        location: _location!,
        currentInstant: currentInstant,
      );
      if (scheduledDate == null) continue;

      await _platform.schedule(
        id: warrantyNotificationIdFor(appliance.id, milestone.daysBefore),
        title:
            '${appliance.name}: ${milestone.daysBefore}-day warranty reminder',
        body: _warrantyNotificationBody(
          expiryDate,
          milestoneDays: milestone.daysBefore,
        ),
        scheduledDate: scheduledDate,
        notificationDetails: _warrantyNotificationDetails,
        payload: WarrantyNotificationPayload(
          applianceId: appliance.id,
          milestoneDays: milestone.daysBefore,
        ).encode(),
      );
    }
  }

  Future<void> _scheduleAmcReminder(Appliance appliance) async {
    final reminderDate = appliance.amcReminderDateAt();
    final expiryDate = appliance.amcExpiryDate;
    if (reminderDate == null || expiryDate == null) return;
    final scheduleDate = ReminderScheduleService.resolve(
      preferredDate: reminderDate,
      dueDate: expiryDate,
      now: _now(),
    );
    if (scheduleDate == null) return;
    final scheduledDate = tz.TZDateTime.from(scheduleDate, _location!);
    final now = tz.TZDateTime.from(_now(), _location!);
    if (!scheduledDate.isAfter(now)) return;
    await _platform.schedule(
      id: amcNotificationIdFor(appliance.id),
      title: '${appliance.name} AMC expires soon',
      body: _amcNotificationBody(appliance, expiryDate),
      scheduledDate: scheduledDate,
      notificationDetails: _amcNotificationDetails,
      payload: '$_amcPayloadPrefix${appliance.id}',
    );
  }

  Future<void> _scheduleServiceReminder(
    Appliance appliance,
    ServiceRecord record,
  ) async {
    final reminderDate = record.reminderDateAt();
    final nextServiceDate = record.nextServiceDate;
    if (reminderDate == null || nextServiceDate == null) return;
    final scheduleDate = ReminderScheduleService.resolve(
      preferredDate: reminderDate,
      dueDate: nextServiceDate,
      now: _now(),
    );
    if (scheduleDate == null) return;
    final scheduledDate = tz.TZDateTime.from(scheduleDate, _location!);
    final now = tz.TZDateTime.from(_now(), _location!);
    if (!scheduledDate.isAfter(now)) return;
    await _platform.schedule(
      id: serviceNotificationIdFor(appliance.id, record.id),
      title: '${appliance.name} service is due soon',
      body: _serviceNotificationBody(record, nextServiceDate),
      scheduledDate: scheduledDate,
      notificationDetails: _serviceNotificationDetails,
      payload: '$_servicePayloadPrefix${appliance.id}|${record.id}',
    );
  }

  Future<void> _cancelFor(String applianceId) async {
    await _cancelWarrantyIds(applianceId);
    final pending = await _platform.pendingNotifications();
    for (final request in pending) {
      if (applianceIdFromPayload(request.payload) == applianceId) {
        await _platform.cancel(request.id);
      }
    }
  }

  Future<void> _cancelWarrantyIds(String applianceId) async {
    await _platform.cancel(
      warrantyNotificationIdFor(
        applianceId,
        WarrantyReminderMilestone.thirtyDays.daysBefore,
      ),
    );
    await _platform.cancel(
      warrantyNotificationIdFor(
        applianceId,
        WarrantyReminderMilestone.sevenDays.daysBefore,
      ),
    );
    await _platform.cancel(notificationIdFor(applianceId));
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
  static const NotificationDetails _amcNotificationDetails =
      NotificationDetails(
        android: AndroidNotificationDetails(
          _amcChannelId,
          _amcChannelName,
          channelDescription: _amcChannelDescription,
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

  /// Legacy warranty ID retained for cancellation compatibility.
  static int notificationIdFor(String applianceId) {
    return _stableNotificationId('warranty|$applianceId');
  }

  static int warrantyNotificationIdFor(String applianceId, int milestoneDays) {
    WarrantyReminderMilestone.fromDays(milestoneDays);
    return _stableNotificationId('warranty|v1|$milestoneDays|$applianceId');
  }

  static int amcNotificationIdFor(String applianceId) {
    return _stableNotificationId('amc|$applianceId');
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
    DateTime expiryDate, {
    required int milestoneDays,
  }) {
    final action = milestoneDays == 30
        ? 'Review coverage and plan any needed service or claim.'
        : 'Act now on any needed service or warranty claim.';
    return 'Effective warranty expires on ${_date(expiryDate)}. $action';
  }

  static String _amcNotificationBody(Appliance appliance, DateTime expiryDate) {
    final provider = appliance.amcProvider.trim();
    final providerText = provider.isEmpty ? '' : ' with $provider';
    return 'AMC$providerText expires on ${_date(expiryDate)}.';
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

  static String? applianceIdFromPayload(String? payload) {
    final value = payload?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('{') || value.startsWith('[')) {
      return WarrantyNotificationPayload.tryParse(value)?.applianceId;
    }
    if (value.startsWith(_servicePayloadPrefix)) {
      final parts = value.split('|');
      if (parts.length != 3 ||
          parts[1].trim().isEmpty ||
          parts[2].trim().isEmpty) {
        return null;
      }
      return parts[1].trim();
    }
    if (value.startsWith(_amcPayloadPrefix)) {
      final parts = value.split('|');
      if (parts.length != 2 || parts[1].trim().isEmpty) return null;
      return parts[1].trim();
    }
    return value;
  }
}

class _PluginWarrantyNotificationPlatform
    implements WarrantyNotificationPlatform {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize({
    required ValueChanged<String?> onNotificationResponse,
  }) async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationResponse(response.payload);
      },
    );
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse?.payload;
  }

  @override
  Future<bool> requestPermission() async {
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

  @override
  Future<bool?> notificationsEnabled() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return androidPlugin?.areNotificationsEnabled();
    }
    return null;
  }

  @override
  Future<List<WarrantyPendingNotification>> pendingNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending
        .map(
          (item) =>
              WarrantyPendingNotification(id: item.id, payload: item.payload),
        )
        .toList(growable: false);
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required NotificationDetails notificationDetails,
    String? payload,
  }) {
    return _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required String payload,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
