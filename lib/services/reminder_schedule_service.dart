class ReminderScheduleService {
  const ReminderScheduleService._();

  static DateTime? resolve({
    required DateTime preferredDate,
    required DateTime dueDate,
    required DateTime now,
    int dueHour = 9,
  }) {
    if (preferredDate.isAfter(now)) return preferredDate;

    final dueFallback = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      dueHour,
    );
    if (dueFallback.isAfter(now)) return dueFallback;
    return null;
  }
}
