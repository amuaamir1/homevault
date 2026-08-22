import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/services/reminder_schedule_service.dart';

void main() {
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
}
