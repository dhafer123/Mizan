import 'package:glados/glados.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/usecases/compute_money_available.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';

const _october = YearMonth(2026, 10);
const _compute = ComputeMoneyAvailable();

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

IncomeSource _monthly(String name, int dinars, int day) => IncomeSource(
  id: name,
  name: name,
  amount: _dt(dinars),
  schedule: IncomeSchedule.monthly(dayOfMonth: day),
);

IncomeSource _oneOff(String name, int dinars, DateTime date) => IncomeSource(
  id: name,
  name: name,
  amount: _dt(dinars),
  schedule: IncomeSchedule.oneOff(date: date),
);

IncomeSource _irregular(String name, int dinars) => IncomeSource(
  id: name,
  name: name,
  amount: _dt(dinars),
  schedule: const IncomeSchedule.irregular(),
);

Expense _expense(int dinars, DateTime date) => Expense(
  id: 'e-${date.toIso8601String()}-$dinars',
  amount: _dt(dinars),
  categoryId: 'food',
  date: date,
);

extension _IncomeAnys on Any {
  Generator<List<IncomeSource>> get incomes =>
      combine2(intInRange(0, 8), intInRange(0, 1 << 32), (int n, int seed) {
        final random = Random(seed);
        return [
          for (var i = 0; i < n; i++)
            IncomeSource(
              id: 's$i',
              name: 'Source $i',
              amount: Money(1 + random.nextInt(2000000), Currency.tnd),
              schedule: switch (random.nextInt(3)) {
                0 => IncomeSchedule.monthly(dayOfMonth: 1 + random.nextInt(31)),
                1 => IncomeSchedule.oneOff(
                  date: DateTime.utc(2026, 8 + random.nextInt(5), 1 + i),
                ),
                _ => const IncomeSchedule.irregular(),
              },
            ),
        ];
      });
}

void main() {
  final today = DateTime.utc(2026, 10, 6);

  test('income minus spending for the month', () {
    final result = _compute(
      month: _october,
      currency: Currency.tnd,
      incomes: [
        _monthly('Grant', 450, 15),
        _irregular('Tutoring', 120),
        _oneOff('Birthday', 50, DateTime.utc(2026, 10, 20)),
        _oneOff('Summer job', 900, DateTime.utc(2026, 8, 1)),
      ],
      expenses: [
        _expense(300, DateTime.utc(2026, 10, 2)),
        _expense(45, DateTime.utc(2026, 10, 5)),
        _expense(999, DateTime.utc(2026, 9, 30)),
      ],
      today: today,
    );

    expect(result.income, _dt(620)); // 450 + 120 + 50
    expect(result.spent, _dt(345));
    expect(result.available, _dt(275));
  });

  test('available is negative when spending runs ahead of income', () {
    final result = _compute(
      month: _october,
      currency: Currency.tnd,
      incomes: [_monthly('Grant', 100, 1)],
      expenses: [_expense(130, DateTime.utc(2026, 10, 3))],
      today: today,
    );

    expect(result.available, _dt(-30));
  });

  test('no income and no spending: everything is zero', () {
    final result = _compute(
      month: _october,
      currency: Currency.tnd,
      incomes: const [],
      expenses: const [],
      today: today,
    );

    expect(result.income, _dt(0));
    expect(result.available, _dt(0));
    expect(result.next, isNull);
  });

  group('monthly payday', () {
    test('is the day of the month', () {
      expect(
        ComputeMoneyAvailable.monthlyPayday(15, _october),
        DateTime.utc(2026, 10, 15),
      );
    });

    test('falls on the last day of a shorter month', () {
      expect(
        ComputeMoneyAvailable.monthlyPayday(31, const YearMonth(2026, 9)),
        DateTime.utc(2026, 9, 30),
      );
      expect(
        ComputeMoneyAvailable.monthlyPayday(30, const YearMonth(2027, 2)),
        DateTime.utc(2027, 2, 28),
      );
      expect(
        ComputeMoneyAvailable.monthlyPayday(30, const YearMonth(2028, 2)),
        DateTime.utc(2028, 2, 29),
      );
    });
  });

  group('next income', () {
    DateTime? nextDate(List<IncomeSource> incomes, DateTime today) =>
        ComputeMoneyAvailable.nextIncome(incomes, today: today)?.date;

    test('later this month', () {
      expect(
        nextDate([_monthly('Grant', 450, 15)], today),
        DateTime.utc(2026, 10, 15),
      );
    });

    test('today on payday', () {
      expect(
        nextDate([_monthly('Grant', 450, 6)], today),
        DateTime.utc(2026, 10, 6),
      );
    });

    test('next month once this month payday has passed', () {
      expect(
        nextDate([_monthly('Grant', 450, 1)], today),
        DateTime.utc(2026, 11, 1),
      );
    });

    test('a day 31 source after 31 January pays on 28 February', () {
      expect(
        nextDate([_monthly('Grant', 450, 31)], DateTime.utc(2027, 2, 1)),
        DateTime.utc(2027, 2, 28),
      );
    });

    test('across the year end', () {
      expect(
        nextDate([_monthly('Grant', 450, 5)], DateTime.utc(2026, 12, 20)),
        DateTime.utc(2027, 1, 5),
      );
    });

    test('a one-off counts until its day, not after', () {
      final birthday = _oneOff('Birthday', 50, DateTime.utc(2026, 10, 20));
      expect(nextDate([birthday], today), DateTime.utc(2026, 10, 20));
      expect(nextDate([birthday], DateTime.utc(2026, 10, 21)), isNull);
    });

    test('irregular income has no date', () {
      expect(nextDate([_irregular('Tutoring', 120)], today), isNull);
    });

    test('the soonest wins; ties go to the name', () {
      final next = ComputeMoneyAvailable.nextIncome([
        _monthly('Grant', 450, 20),
        _oneOff('Birthday', 50, DateTime.utc(2026, 10, 9)),
        _monthly('Allowance', 100, 9),
      ], today: today);

      expect(next!.date, DateTime.utc(2026, 10, 9));
      expect(next.source.name, 'Allowance');
    });

    test('today is read as a calendar day in its own time zone', () {
      expect(
        nextDate([_monthly('Grant', 450, 6)], DateTime(2026, 10, 6, 23, 59)),
        DateTime.utc(2026, 10, 6),
      );
    });
  });

  Glados(any.incomes).test(
    'income is the monthly and irregular sources plus one-offs in the month',
    (incomes) {
      final result = _compute(
        month: _october,
        currency: Currency.tnd,
        incomes: incomes,
        expenses: const [],
        today: today,
      );

      var expected = 0;
      for (final source in incomes) {
        final counts = switch (source.schedule) {
          MonthlyIncome() || IrregularIncome() => true,
          OneOffIncome(:final date) => date.year == 2026 && date.month == 10,
        };
        if (counts) expected += source.amount.minorUnits;
      }
      expect(result.income, Money(expected, Currency.tnd));
      expect(result.available + result.spent, result.income);

      final next = result.next;
      if (next != null) {
        expect(next.date.isBefore(today), isFalse);
        expect(next.source.schedule, isNot(isA<IrregularIncome>()));
      }
    },
  );
}
