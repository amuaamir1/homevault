enum HomeVaultReminderType { warranty, amc, maintenance }

extension HomeVaultReminderTypeDetails on HomeVaultReminderType {
  String get label => switch (this) {
    HomeVaultReminderType.warranty => 'Warranty',
    HomeVaultReminderType.amc => 'AMC',
    HomeVaultReminderType.maintenance => 'Maintenance',
  };
}

enum HomeVaultReminderTiming { overdue, today, dueSoon, upcoming }

class HomeVaultReminder {
  const HomeVaultReminder({
    required this.id,
    required this.type,
    required this.applianceId,
    required this.applianceName,
    required this.dueDate,
    required this.notificationEnabled,
    required this.reminderDaysBefore,
    this.provider = '',
    this.serviceRecordId,
    this.notificationDate,
  });

  final String id;
  final HomeVaultReminderType type;
  final String applianceId;
  final String applianceName;
  final DateTime dueDate;
  final bool notificationEnabled;
  final int reminderDaysBefore;
  final String provider;
  final String? serviceRecordId;
  final DateTime? notificationDate;

  int daysUntilDueAt(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return dueDay.difference(today).inDays;
  }

  HomeVaultReminderTiming timingAt(DateTime now) {
    final days = daysUntilDueAt(now);
    if (days < 0) return HomeVaultReminderTiming.overdue;
    if (days == 0) return HomeVaultReminderTiming.today;
    if (days <= 30) return HomeVaultReminderTiming.dueSoon;
    return HomeVaultReminderTiming.upcoming;
  }

  bool needsAttentionAt(DateTime now, {int windowDays = 30}) {
    final days = daysUntilDueAt(now);
    return days >= -windowDays && days <= windowDays;
  }

  bool reminderWindowHasStartedAt(DateTime now) {
    final date = notificationDate;
    if (!notificationEnabled || date == null) return false;
    return !date.isAfter(now) && daysUntilDueAt(now) >= 0;
  }
}
