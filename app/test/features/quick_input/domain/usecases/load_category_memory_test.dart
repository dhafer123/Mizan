import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_failure.dart';
import 'package:mizan/features/quick_input/domain/usecases/load_category_memory.dart';

import '../../../../support/fake_expense_repository.dart';

void main() {
  test("learns from the user's expenses", () async {
    final repository = FakeExpenseRepository([
      Expense(
        id: 'e1',
        amount: const Money(2000, Currency.tnd),
        categoryId: 'leisure',
        date: DateTime.utc(2026, 10, 2),
        note: 'Café Le Baron',
      ),
      Expense(
        id: 'e2',
        amount: const Money(2000, Currency.tnd),
        categoryId: 'food',
        date: DateTime.utc(2026, 10, 3),
      ),
    ]);
    final memory = (await LoadCategoryMemory(repository)()).valueOrNull!;
    expect(memory.notes, {'cafe le baron': 'leisure'});
    expect(memory.words.keys, ['baron']); // "cafe" is a keyword.
  });

  test('a storage failure is passed on', () async {
    final repository = _FailingRepository();
    expect(
      await LoadCategoryMemory(repository)(),
      const Err<Object?, ExpenseFailure>(ExpenseFailure(ExpenseError.storage)),
    );
  });
}

class _FailingRepository extends FakeExpenseRepository {
  @override
  Future<Result<List<Expense>, ExpenseFailure>> getAll() async =>
      const Err(ExpenseFailure(ExpenseError.storage));
}
