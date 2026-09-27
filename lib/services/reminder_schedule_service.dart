import 'package:timezone/timezone.dart' as tz;

import '../models/appliance.dart';

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

  static tz.TZDateTime warrantyCandidate({
    required DateTime effectiveExpiryDate,
    required WarrantyReminderMilestone milestone,
    required tz.Location location,
    int hour = 9,
  }) {
    final candidateDay = DateTime.utc(
      effectiveExpiryDate.year,
      effectiveExpiryDate.month,
      effectiveExpiryDate.day - milestone.daysBefore,
    );
    return tz.TZDateTime(
      location,
      candidateDay.year,
      candidateDay.month,
      candidateDay.day,
      hour,
    );
  }

  static tz.TZDateTime? eligibleWarrantyCandidate({
    required DateTime effectiveExpiryDate,
    required WarrantyReminderMilestone milestone,
    required tz.Location location,
    required DateTime currentInstant,
    int hour = 9,
  }) {
    final candidate = warrantyCandidate(
      effectiveExpiryDate: effectiveExpiryDate,
      milestone: milestone,
      location: location,
      hour: hour,
    );
    return candidate.isAfter(currentInstant) ? candidate : null;
  }
}
