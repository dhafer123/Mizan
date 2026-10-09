import '../../../../core/clock/calendar_day.dart';
import '../../../../core/ids/uuid_v7_time.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/domain/value_objects/expense_source.dart';
import '../value_objects/usage_day.dart';

/// Counts [Expense]s by the day they were logged and how (typed, voice,
/// receipt), for every day from [since] (the opt-in day) to today, at most
/// the last [window] days. Days with nothing logged are 0, so a resent day
/// whose expense was deleted goes back down.
///
/// The logged moment is read from the expense's UUIDv7 id (no extra column),
/// on the phone's local calendar; ids that aren't v7 are skipped. Only live
/// expenses are counted.
class BuildUsageReport {
  const BuildUsageReport();

  static const window = 14;

  /// [since] and [today] are calendar days (UTC midnight).
  List<UsageDay> call({
    required List<Expense> expenses,
    required DateTime since,
    required DateTime today,
  }) {
    final earliest = today.subtract(const Duration(days: window - 1));
    final from = since.isAfter(earliest) ? since : earliest;
    final days = <DateTime, UsageDay>{
      for (var day = from; !day.isAfter(today); day = _next(day))
        day: UsageDay(day: day),
    };
    for (final expense in expenses) {
      final day = uuidV7Time(expense.id)?.calendarDay;
      final counted = days[day];
      if (day == null || counted == null) continue;
      days[day] = switch (expense.source) {
        ExpenseSource.manual => counted.copyWith(manual: counted.manual + 1),
        ExpenseSource.voice => counted.copyWith(voice: counted.voice + 1),
        ExpenseSource.receipt => counted.copyWith(receipt: counted.receipt + 1),
      };
    }
    return days.values.toList();
  }

  // Calendar days are UTC, so adding 24 hours never skips or repeats one.
  static DateTime _next(DateTime day) => day.add(const Duration(days: 1));
}
