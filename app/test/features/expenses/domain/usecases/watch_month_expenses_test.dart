import 'package:glados/glados.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/expenses/domain/usecases/watch_month_expenses.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_day.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_failure.dart';

import '../../../../support/fake_expense_repository.dart';

const _october = YearMonth(2026, 10);

Expense _expense(String id, int day, int millimes) => Expense(
  id: id,
  amount: Money(millimes, Currency.tnd),
  categoryId: 'food',
  date: DateTime.utc(2026, 10, day),
);

/// 0-40 October expenses with unique ids, clustered on a few days.
extension _ExpenseAnys on Any {
  Generator<List<Expense>> get octoberExpenses => combine2(
    intInRange(0, 41),
    intInRange(0, 1 << 32),
    (int count, int seed) {
      final random = Random(seed);
      final ids = <String>{};
      while (ids.length < count) {
        ids.add(random.nextInt(1 << 30).toRadixString(16).padLeft(8, '0'));
      }
      return [
        for (final id in ids)
          _expense(id, 1 + random.nextInt(5) * 7, 1 + random.nextInt(99999)),
      ];
    },
  );
}

void main() {
  Future<List<ExpenseDay>> firstEmission(List<Expense> expenses) async {
    final watch = WatchMonthExpenses(FakeExpenseRepository(expenses));
    return (await watch(_october).first).valueOrNull!;
  }

  test('groups by day, newest day first and newest (by id) first', () async {
    final days = await firstEmission([
      _expense('01', 3, 1000),
      _expense('03', 6, 2000),
      _expense('02', 3, 500),
      _expense('04', 6, 4500),
    ]);

    expect(days, [
      ExpenseDay(
        day: DateTime.utc(2026, 10, 6),
        expenses: [_expense('04', 6, 4500), _expense('03', 6, 2000)],
      ),
      ExpenseDay(
        day: DateTime.utc(2026, 10, 3),
        expenses: [_expense('02', 3, 500), _expense('01', 3, 1000)],
      ),
    ]);
    expect(days.map((d) => d.total), [
      const Money(6500, Currency.tnd),
      const Money(1500, Currency.tnd),
    ]);
  });

  test('an empty month has no days', () async {
    expect(await firstEmission([]), isEmpty);
  });

  test('re-emits when the expenses change', () async {
    final repository = FakeExpenseRepository();
    final emissions = WatchMonthExpenses(repository)(
      _october,
    ).map((r) => r.valueOrNull!.length).take(2).toList();

    await Future<void>.delayed(Duration.zero);
    await repository.add(_expense('01', 3, 1000));

    expect(await emissions, [0, 1]);
  });

  test('passes failures through', () async {
    final repository = FakeExpenseRepository()
      ..watchFailure = const ExpenseFailure(ExpenseError.storage);

    final result = await WatchMonthExpenses(repository)(_october).first;

    expect(result.failureOrNull?.error, ExpenseError.storage);
  });

  Glados(any.octoberExpenses).test(
    'keeps every expense exactly once, in order, and the totals add up',
    (expenses) async {
      final days = await firstEmission(expenses);
      final flattened = [for (final day in days) ...day.expenses];

      expect(flattened, unorderedEquals(expenses));
      for (final day in days) {
        expect(day.expenses, isNotEmpty);
        expect(day.expenses.every((e) => e.date == day.day), isTrue);
      }
      for (var i = 1; i < days.length; i++) {
        expect(days[i].day.isBefore(days[i - 1].day), isTrue);
      }
      for (var i = 1; i < flattened.length; i++) {
        final (a, b) = (flattened[i - 1], flattened[i]);
        if (a.date == b.date) expect(a.id.compareTo(b.id), isPositive);
      }
      expect(
        Money.sum(days.map((d) => d.total), Currency.tnd),
        Money.sum(expenses.map((e) => e.amount), Currency.tnd),
      );
    },
  );
}
