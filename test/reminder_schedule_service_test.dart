import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/services/reminder_schedule_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('keeps a future preferred reminder date', () {
    final preferred = DateTime(2026, 9, 1, 9);

    final result = ReminderScheduleService.resolve(
      preferredDate: preferred,
      dueDate: DateTime(2026, 9, 30),
      now: DateTime(2026, 8, 23, 12),
    );

    expect(result, preferred);
  });

  test('falls back to due-date notification when reminder window passed', () {
    final result = ReminderScheduleService.resolve(
      preferredDate: DateTime(2026, 8, 1, 9),
      dueDate: DateTime(2026, 8, 30),
      now: DateTime(2026, 8, 23, 12),
    );

    expect(result, DateTime(2026, 8, 30, 9));
  });

  test('does not schedule after the due-date fallback has passed', () {
    final result = ReminderScheduleService.resolve(
      preferredDate: DateTime(2026, 8, 1, 9),
      dueDate: DateTime(2026, 8, 23),
      now: DateTime(2026, 8, 23, 12),
    );

    expect(result, isNull);
  });

  test('warranty eligibility is strict before, at, and after local 09:00', () {
    final location = tz.getLocation('Asia/Kolkata');
    final candidate = ReminderScheduleService.warrantyCandidate(
      effectiveExpiryDate: DateTime(2026, 10, 30),
      milestone: WarrantyReminderMilestone.thirtyDays,
      location: location,
    );

    expect(candidate, tz.TZDateTime(location, 2026, 9, 30, 9));
    expect(
      ReminderScheduleService.eligibleWarrantyCandidate(
        effectiveExpiryDate: DateTime(2026, 10, 30),
        milestone: WarrantyReminderMilestone.thirtyDays,
        location: location,
        currentInstant: candidate.subtract(const Duration(seconds: 1)),
      ),
      candidate,
    );
    expect(
      ReminderScheduleService.eligibleWarrantyCandidate(
        effectiveExpiryDate: DateTime(2026, 10, 30),
        milestone: WarrantyReminderMilestone.thirtyDays,
        location: location,
        currentInstant: candidate,
      ),
      isNull,
    );
    expect(
      ReminderScheduleService.eligibleWarrantyCandidate(
        effectiveExpiryDate: DateTime(2026, 10, 30),
        milestone: WarrantyReminderMilestone.thirtyDays,
        location: location,
        currentInstant: candidate.add(const Duration(seconds: 1)),
      ),
      isNull,
    );
  });

  test('calendar subtraction constructs 09:00 after a DST transition', () {
    final location = tz.getLocation('America/New_York');
    final candidate = ReminderScheduleService.warrantyCandidate(
      effectiveExpiryDate: DateTime(2026, 11, 7),
      milestone: WarrantyReminderMilestone.sevenDays,
      location: location,
    );

    expect(candidate.year, 2026);
    expect(candidate.month, 10);
    expect(candidate.day, 31);
    expect(candidate.hour, 9);
    expect(candidate.timeZoneOffset, const Duration(hours: -4));
  });
}
