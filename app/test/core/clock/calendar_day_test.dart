import 'package:mizan/core/clock/calendar_day.dart';
import 'package:test/test.dart';

void main() {
  test('takes the date as read in the moment own time zone', () {
    expect(
      DateTime(2026, 10, 6, 23, 30).calendarDay,
      DateTime.utc(2026, 10, 6),
    );
    expect(
      DateTime.utc(2026, 10, 6, 23, 59).calendarDay,
      DateTime.utc(2026, 10, 6),
    );
  });

  test('is idempotent', () {
    final day = DateTime.utc(2026, 2, 28);
    expect(day.calendarDay, day);
  });

  test('isCalendarDay is true only for UTC midnight', () {
    expect(DateTime.utc(2026, 10, 6).isCalendarDay, isTrue);
    expect(DateTime.utc(2026, 10, 6, 0, 0, 0, 1).isCalendarDay, isFalse);
    expect(DateTime.utc(2026, 10, 6, 0, 0, 0, 0, 1).isCalendarDay, isFalse);
    expect(DateTime.utc(2026, 10, 6, 1).isCalendarDay, isFalse);
    expect(DateTime(2026, 10, 6).isCalendarDay, isFalse);
  });
}
