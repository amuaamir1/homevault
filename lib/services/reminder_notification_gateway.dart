import '../models/appliance.dart';
import 'warranty_notification_service.dart';

abstract class ReminderNotificationGateway {
  Future<bool> requestPermission();

  Future<bool?> notificationsEnabled();

  Future<int> pendingReminderCount();

  Future<void> showTestNotification({Appliance? appliance});
}

class LocalReminderNotificationGateway implements ReminderNotificationGateway {
  LocalReminderNotificationGateway({WarrantyNotificationService? service})
    : _service = service ?? WarrantyNotificationService.instance;

  final WarrantyNotificationService _service;

  @override
  Future<bool> requestPermission() => _service.requestPermission();

  @override
  Future<bool?> notificationsEnabled() => _service.notificationsEnabled();

  @override
  Future<int> pendingReminderCount() => _service.pendingReminderCount();

  @override
  Future<void> showTestNotification({Appliance? appliance}) =>
      _service.showTestNotification(appliance: appliance);
}
