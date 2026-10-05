import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/expenses/domain/usecases/add_expense.dart';
import 'package:mizan/features/expenses/domain/usecases/delete_expense.dart';
import 'package:mizan/features/expenses/domain/usecases/validate_expense.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_error.dart';
import 'package:test/test.dart';

import '../../../../support/fake_expense_repository.dart';
import '../../../../support/sequential_id_generator.dart';

Money _dt(int millimes) => Money(millimes, Currency.tnd);

void main() {
  late FakeExpenseRepository repository;
  late AddExpense addExpense;
  late DeleteExpense deleteExpense;

  setUp(() {
    repository = FakeExpenseRepository();
    final validate = ValidateExpense(FakeClock(DateTime.utc(2026, 10, 6, 9)));
    addExpense = AddExpense(
      repository,
      SequentialIdGenerator(prefix: 'e'),
      validate,
    );
    deleteExpense = DeleteExpense(repository);
  });

  group('DeleteExpense', () {
    test('removes the expense', () async {
      final saved = (await addExpense(
        amount: _dt(4500),
        categoryId: 'food',
        date: DateTime.utc(2026, 10, 6),
      )).valueOrNull!;

      expect((await deleteExpense(saved.id)).isOk, isTrue);
      expect(repository.live, isEmpty);
    });

    test('fails for an unknown id', () async {
      final result = await deleteExpense('nope');
      expect(result.failureOrNull?.error, ExpenseError.notFound);
    });
  });
}
