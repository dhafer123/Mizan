import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/expenses/domain/usecases/add_expenses.dart';
import 'package:mizan/features/expenses/domain/usecases/validate_expense.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_failure.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_item_failure.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_source.dart';
import 'package:test/test.dart';

import '../../../../support/fake_expense_repository.dart';
import '../../../../support/sequential_id_generator.dart';

Money _dt(int millimes) => Money(millimes, Currency.tnd);

final _today = DateTime.utc(2026, 10, 6);

NewExpense _new(int millimes, {String category = 'food', String? note}) =>
    (amount: _dt(millimes), categoryId: category, date: _today, note: note);

void main() {
  late FakeExpenseRepository repository;
  late AddExpenses addExpenses;

  setUp(() {
    repository = FakeExpenseRepository();
    addExpenses = AddExpenses(
      repository,
      SequentialIdGenerator(prefix: 'e'),
      ValidateExpense(FakeClock(DateTime.utc(2026, 10, 6, 9))),
    );
  });

  test('saves all, in order, with fresh ids and the source', () async {
    final result = await addExpenses([
      _new(1500, note: 'kahwa'),
      _new(8000, category: 'transport', note: 'taxi'),
    ], source: ExpenseSource.voice);

    final saved = result.valueOrNull!;
    expect(saved.map((e) => (e.id, e.note, e.source)), [
      ('e1', 'kahwa', ExpenseSource.voice),
      ('e2', 'taxi', ExpenseSource.voice),
    ]);
    expect(repository.live, unorderedEquals(saved));
  });

  test('one invalid expense saves none and names which', () async {
    final result = await addExpenses([
      _new(1500),
      _new(0),
    ], source: ExpenseSource.manual);

    expect(
      result,
      const Err<List<Expense>, ExpenseFailure>(
        ExpenseItemFailure(1, ExpenseError.amountNotPositive),
      ),
    );
    expect((result as Err).failure.message, 'The amount must be more than 0.');
    expect(repository.live, isEmpty);
  });

  test('a storage failure saves none', () async {
    repository.writeFailure = const ExpenseFailure(ExpenseError.storage);
    final result = await addExpenses([_new(1500)], source: ExpenseSource.voice);
    expect(
      result,
      const Err<List<Expense>, ExpenseFailure>(
        ExpenseFailure(ExpenseError.storage),
      ),
    );
  });

  test('nothing to add is fine', () async {
    final result = await addExpenses(const [], source: ExpenseSource.voice);
    expect(result.valueOrNull, isEmpty);
  });
}
