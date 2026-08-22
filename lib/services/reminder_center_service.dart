import '../models/appliance.dart';
import '../models/homevault_reminder.dart';

class ReminderCenterSummary {
  const ReminderCenterSummary({
    required this.total,
    required this.attention,
    required this.overdue,
    required this.next30Days,
    required this.notificationsOn,
    required this.notificationsOff,
  });

  final int total;
  final int attention;
  final int overdue;
  final int next30Days;
  final int notificationsOn;
  final int notificationsOff;
}

class ReminderCenterService {
  const ReminderCenterService();

  List<HomeVaultReminder> build(
    Iterable<Appliance> appliances, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final reminders = <HomeVaultReminder>[];

    for (final appliance in appliances) {
      _addWarrantyReminder(reminders, appliance);
      _addAmcReminder(reminders, appliance);
      _addMaintenanceReminder(reminders, appliance);
    }

    reminders.sort((a, b) => _compare(a, b, reference));
    return List.unmodifiable(reminders);
  }

  ReminderCenterSummary summarize(
    Iterable<HomeVaultReminder> reminders, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    var total = 0;
    var attention = 0;
    var overdue = 0;
    var next30Days = 0;
    var notificationsOn = 0;
    var notificationsOff = 0;

    for (final reminder in reminders) {
      total++;
      final days = reminder.daysUntilDueAt(reference);
      if (reminder.needsAttentionAt(reference)) attention++;
      if (days < 0) overdue++;
      if (days >= 0 && days <= 30) next30Days++;
      if (reminder.notificationEnabled) {
        notificationsOn++;
      } else {
        notificationsOff++;
      }
    }

    return ReminderCenterSummary(
      total: total,
      attention: attention,
      overdue: overdue,
      next30Days: next30Days,
      notificationsOn: notificationsOn,
      notificationsOff: notificationsOff,
    );
  }

  void _addWarrantyReminder(
    List<HomeVaultReminder> reminders,
    Appliance appliance,
  ) {
    if (appliance.warrantyMarkedExpired) return;
    final expiry = appliance.effectiveWarrantyExpiryDate;
    if (expiry == null) return;

    reminders.add(
      HomeVaultReminder(
        id: 'warranty|${appliance.id}',
        type: HomeVaultReminderType.warranty,
        applianceId: appliance.id,
        applianceName: appliance.name,
        dueDate: expiry,
        notificationEnabled: appliance.warrantyReminderEnabled,
        reminderDaysBefore: appliance.warrantyReminderDaysBefore,
        provider: _warrantyProvider(appliance, expiry),
        notificationDate: appliance.warrantyReminderDateAt(),
      ),
    );
  }

  void _addAmcReminder(List<HomeVaultReminder> reminders, Appliance appliance) {
    final expiry = appliance.amcExpiryDate;
    if (expiry == null) return;

    reminders.add(
      HomeVaultReminder(
        id: 'amc|${appliance.id}',
        type: HomeVaultReminderType.amc,
        applianceId: appliance.id,
        applianceName: appliance.name,
        dueDate: expiry,
        notificationEnabled: appliance.amcReminderEnabled,
        reminderDaysBefore: appliance.amcReminderDaysBefore,
        provider: appliance.amcProvider.trim(),
        notificationDate: appliance.amcReminderDateAt(),
      ),
    );
  }

  void _addMaintenanceReminder(
    List<HomeVaultReminder> reminders,
    Appliance appliance,
  ) {
    final record = appliance.maintenanceScheduleRecord;
    final dueDate = record?.nextServiceDate;
    if (record == null || dueDate == null) return;

    reminders.add(
      HomeVaultReminder(
        id: 'maintenance|${appliance.id}|${record.id}',
        type: HomeVaultReminderType.maintenance,
        applianceId: appliance.id,
        applianceName: appliance.name,
        dueDate: dueDate,
        notificationEnabled: record.reminderEnabled,
        reminderDaysBefore: record.reminderDaysBefore,
        provider: record.provider.trim(),
        serviceRecordId: record.id,
        notificationDate: record.reminderDateAt(),
      ),
    );
  }

  String _warrantyProvider(Appliance appliance, DateTime effectiveExpiry) {
    final extendedExpiry = appliance.extendedWarrantyExpiryDate;
    if (extendedExpiry != null &&
        _sameDay(extendedExpiry, effectiveExpiry) &&
        appliance.extendedWarrantyProvider.trim().isNotEmpty) {
      return appliance.extendedWarrantyProvider.trim();
    }
    return appliance.warrantyProvider.trim();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _compare(HomeVaultReminder a, HomeVaultReminder b, DateTime reference) {
    final aDays = a.daysUntilDueAt(reference);
    final bDays = b.daysUntilDueAt(reference);
    final aGroup = _sortGroup(aDays);
    final bGroup = _sortGroup(bDays);

    final groupComparison = aGroup.compareTo(bGroup);
    if (groupComparison != 0) return groupComparison;

    if (aDays < 0 && bDays < 0) {
      final recentOverdue = b.dueDate.compareTo(a.dueDate);
      if (recentOverdue != 0) return recentOverdue;
    } else {
      final dueComparison = a.dueDate.compareTo(b.dueDate);
      if (dueComparison != 0) return dueComparison;
    }

    final applianceComparison = a.applianceName.toLowerCase().compareTo(
      b.applianceName.toLowerCase(),
    );
    if (applianceComparison != 0) return applianceComparison;
    return a.type.index.compareTo(b.type.index);
  }

  int _sortGroup(int daysUntilDue) {
    if (daysUntilDue < 0) return 0;
    if (daysUntilDue == 0) return 1;
    if (daysUntilDue <= 30) return 2;
    return 3;
  }
}
