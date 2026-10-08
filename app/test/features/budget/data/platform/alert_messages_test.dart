import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/data/platform/alert_messages.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_alert.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:mizan/features/budget/domain/value_objects/next_income.dart';

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

BudgetAlert _food(int spent) => BudgetAlert.categoryLimit(
  categoryId: 'food',
  categoryName: 'Food',
  month: const YearMonth(2026, 10),
  spent: _dt(spent),
  limit: _dt(150),
  usedPercent: spent * 100 ~/ 150,
);

void main() {
  test('category near its limit', () {
    expect(AlertMessages.of(_food(127)), (
      'Food: 84% of its limit used',
      '127.000 DT of 150.000 DT this month, 23.000 DT left.',
    ));
  });

  test('category over its limit', () {
    expect(AlertMessages.of(_food(180)), (
      'Food is over its limit',
      '180.000 DT of 150.000 DT this month.',
    ));
  });

  test('run-out before the next income', () {
    final alert = BudgetAlert.runOut(
      runOut: DateTime.utc(2026, 10, 22),
      next: NextIncome(
        source: IncomeSource(
          id: 'g',
          name: 'Grant',
          amount: _dt(300),
          schedule: const IncomeSchedule.monthly(dayOfMonth: 25),
        ),
        date: DateTime.utc(2026, 10, 25),
      ),
    );
    expect(AlertMessages.of(alert), (
      'Your money may run out before Grant',
      'At this pace it runs out around Oct 22; Grant comes on Oct 25.',
    ));
  });

  test('run-out with no income scheduled', () {
    final alert = BudgetAlert.runOut(runOut: DateTime.utc(2026, 12, 1));
    expect(AlertMessages.of(alert), (
      'Your money may run out by Dec 1',
      'At this pace it runs out around Dec 1, and no income is scheduled.',
    ));
  });

  test('unusual expense, with how many times the usual it is', () {
    final alert = BudgetAlert.unusualSpending(
      expenseId: 'e',
      categoryName: 'Food',
      date: DateTime.utc(2026, 10, 20),
      amount: _dt(90),
      median: _dt(12),
    );
    expect(AlertMessages.of(alert), (
      'Unusual Food expense: 90.000 DT',
      'About 8× your usual 12.000 DT for Food.',
    ));
  });
}
