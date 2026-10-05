import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/expenses/domain/usecases/add_expense.dart';
import 'package:mizan/features/expenses/domain/usecases/validate_expense.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_failure.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_source.dart';
import 'package:test/test.dart';

import '../../../../support/fake_expense_repository.dart';
import '../../../../support/sequential_id_generator.dart';

Money _dt(int millimes) => Money(millimes, Currency.tnd);

void main() {
  late FakeExpenseRepository repository;
  late AddExpense addExpense;

  setUp(() {
    repository = FakeExpenseRepository();
    final validate = ValidateExpense(FakeClock(DateTime.utc(2026, 10, 6, 9)));
    addExpense = AddExpense(
      repository,
      SequentialIdGenerator(prefix: 'e'),
      validate,
    );
  });

  group('AddExpense', () {
    test('saves a new expense with a fresh id and returns it', () async {
      final result = await addExpense(
        amount: _dt(4500),
        categoryId: 'food',
        date: DateTime(2026, 10, 6, 13, 10),
        note: ' coffee ',
        source: ExpenseSource.voice,
      );

      final expected = Expense(
        id: 'e1',
        amount: _dt(4500),
        categoryId: 'food',
        date: DateTime.utc(2026, 10, 6),
        note: 'coffee',
        source: ExpenseSource.voice,
      );
      expect(result, Ok<Expense, ExpenseFailure>(expected));
      expect(repository.live, [expected]);
    });

    test('defaults to manual entry', () async {
      final result = await addExpense(
        amount: _dt(1),
        categoryId: 'food',
        date: DateTime.utc(2026, 10, 6),
      );
      expect(result.valueOrNull!.source, ExpenseSource.manual);
    });

    test('saves nothing when invalid', () async {
      final result = await addExpense(
        amount: _dt(0),
        categoryId: 'food',
        date: DateTime.utc(2026, 10, 6),
      );

      expect(
        result.failureOrNull,
        const ExpenseFailure(ExpenseError.amountNotPositive),
      );
      expect(repository.live, isEmpty);
    });

    test('passes on a storage failure', () async {
      repository.writeFailure = const ExpenseFailure(ExpenseError.storage);

      final result = await addExpense(
        amount: _dt(1),
        categoryId: 'food',
        date: DateTime.utc(2026, 10, 6),
      );

      expect(result.failureOrNull?.error, ExpenseError.storage);
    });
  });
}
