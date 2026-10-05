import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/expenses/domain/usecases/add_expense.dart';
import 'package:mizan/features/expenses/domain/usecases/delete_expense.dart';
import 'package:mizan/features/expenses/domain/usecases/edit_expense.dart';
import 'package:mizan/features/expenses/domain/usecases/validate_expense.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_failure.dart';
import 'package:test/test.dart';

import '../../../../support/fake_expense_repository.dart';
import '../../../../support/sequential_id_generator.dart';

Money _dt(int millimes) => Money(millimes, Currency.tnd);

void main() {
  late FakeExpenseRepository repository;
  late AddExpense addExpense;
  late EditExpense editExpense;
  late DeleteExpense deleteExpense;

  setUp(() {
    repository = FakeExpenseRepository();
    final validate = ValidateExpense(FakeClock(DateTime.utc(2026, 10, 6, 9)));
    addExpense = AddExpense(
      repository,
      SequentialIdGenerator(prefix: 'e'),
      validate,
    );
    editExpense = EditExpense(repository, validate);
    deleteExpense = DeleteExpense(repository);
  });

  group('EditExpense', () {
    late Expense saved;

    setUp(() async {
      saved = (await addExpense(
        amount: _dt(4500),
        categoryId: 'food',
        date: DateTime.utc(2026, 10, 6),
      )).valueOrNull!;
    });

    test('saves the validated changes and returns them', () async {
      final result = await editExpense(
        saved.copyWith(amount: _dt(5000), note: '  big coffee'),
      );

      final expected = saved.copyWith(amount: _dt(5000), note: 'big coffee');
      expect(result, Ok<Expense, ExpenseFailure>(expected));
      expect(repository.live, [expected]);
    });

    test('changes nothing when invalid', () async {
      final result = await editExpense(saved.copyWith(categoryId: ''));

      expect(result.failureOrNull?.error, ExpenseError.noCategory);
      expect(repository.live, [saved]);
    });

    test('fails for an expense that is gone', () async {
      await deleteExpense(saved.id);

      final result = await editExpense(saved.copyWith(amount: _dt(1)));

      expect(result.failureOrNull?.error, ExpenseError.notFound);
    });
  });
}
