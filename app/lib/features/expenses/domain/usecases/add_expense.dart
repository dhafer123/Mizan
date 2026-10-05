import '../../../../core/ids/id_generator.dart';
import '../../../../core/money/money.dart';
import '../../../../core/result/result.dart';
import '../entities/expense.dart';
import '../repositories/expense_repository.dart';
import '../value_objects/expense_failure.dart';
import '../value_objects/expense_source.dart';
import 'validate_expense.dart';

/// Records a new personal expense. Returns it as saved.
class AddExpense {
  const AddExpense(this._repository, this._ids, this._validate);

  final ExpenseRepository _repository;
  final IdGenerator _ids;
  final ValidateExpense _validate;

  Future<Result<Expense, ExpenseFailure>> call({
    required Money amount,
    required String categoryId,
    required DateTime date,
    String? note,
    ExpenseSource source = ExpenseSource.manual,
  }) async {
    final validated = _validate(
      Expense(
        id: _ids.newId(),
        amount: amount,
        categoryId: categoryId,
        date: date,
        note: note,
        source: source,
      ),
    );
    switch (validated) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final expense):
        final saved = await _repository.add(expense);
        return saved.map((_) => expense);
    }
  }
}
