import 'package:glados/glados.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/ids/uuid_v7_generator.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/beta/domain/usecases/build_usage_report.dart';
import 'package:mizan/features/beta/domain/value_objects/usage_day.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_source.dart';

/// An expense logged at local noon on 2026-10-[day] (any time zone gives
/// the same calendar day), with [source].
Expense logged(int day, ExpenseSource source, {int hour = 12}) => Expense(
  id: UuidV7Generator(FakeClock(DateTime(2026, 10, day, hour))).newId(),
  amount: const Money(1500, Currency.tnd),
  categoryId: 'food',
  // The spending date doesn't matter: only when it was logged.
  date: DateTime.utc(2026, 9, 1),
  source: source,
);

DateTime oct(int day) => DateTime.utc(2026, 10, day);

void main() {
  const build = BuildUsageReport();

  test('counts each day by input method, with 0 for quiet days', () {
    final days = build(
      expenses: [
        logged(7, ExpenseSource.manual),
        logged(7, ExpenseSource.manual),
        logged(7, ExpenseSource.voice),
        logged(9, ExpenseSource.receipt),
        logged(9, ExpenseSource.manual, hour: 23),
      ],
      since: oct(7),
      today: oct(9),
    );

    expect(days, [
      UsageDay(day: oct(7), manual: 2, voice: 1),
      UsageDay(day: oct(8)),
      UsageDay(day: oct(9), manual: 1, receipt: 1),
    ]);
  });

  test('nothing from before the opt-in day', () {
    final days = build(
      expenses: [
        logged(5, ExpenseSource.manual),
        logged(6, ExpenseSource.voice),
      ],
      since: oct(6),
      today: oct(6),
    );

    expect(days, [UsageDay(day: oct(6), voice: 1)]);
  });

  test('at most the last 14 days', () {
    final days = build(
      expenses: [
        logged(1, ExpenseSource.manual),
        logged(2, ExpenseSource.manual),
        logged(15, ExpenseSource.voice),
      ],
      since: oct(1),
      today: oct(15),
    );

    expect(days, hasLength(BuildUsageReport.window));
    expect(days.first, UsageDay(day: oct(2), manual: 1));
    expect(days.last, UsageDay(day: oct(15), voice: 1));
  });

  test('skips ids that are not UUIDv7 and expenses logged after today', () {
    final days = build(
      expenses: [
        logged(9, ExpenseSource.manual).copyWith(id: 'imported-1'),
        logged(10, ExpenseSource.manual),
      ],
      since: oct(9),
      today: oct(9),
    );

    expect(days, [UsageDay(day: oct(9))]);
  });

  test('a clock set back before the opt-in day gives no days', () {
    expect(build(expenses: const [], since: oct(9), today: oct(8)), isEmpty);
  });

  Glados3(
    any.listWithLengthInRange(0, 40, any.intInRange(1, 31)),
    any.intInRange(1, 31),
    any.intInRange(1, 31),
  ).test('every expense logged in the window is counted exactly once', (
    loggedDays,
    sinceDay,
    todayDay,
  ) {
    final sources = ExpenseSource.values;
    final expenses = [
      for (final (i, day) in loggedDays.indexed)
        logged(day, sources[i % sources.length]),
    ];
    final days = build(
      expenses: expenses,
      since: oct(sinceDay),
      today: oct(todayDay),
    );

    final from = sinceDay > todayDay - 13 ? sinceDay : todayDay - 13;
    final inWindow = loggedDays.where((d) => d >= from && d <= todayDay);
    final counted = days.fold(
      0,
      (sum, d) => sum + d.manual + d.voice + d.receipt,
    );
    expect(counted, inWindow.length);
    expect(days.map((d) => d.day), [
      for (var d = from; d <= todayDay; d++) oct(d),
    ]);
  });
}
