import '../../../../core/result/result.dart';
import '../entities/expense.dart';
import '../repositories/expense_repository.dart';
import '../value_objects/expense_failure.dart';
import 'validate_expense.dart';

/// Saves changes to an existing expense. Returns it as saved.
class EditExpense {
  const EditExpense(this._repository, this._validate);

  final ExpenseRepository _repository;
  final ValidateExpense _validate;

  Future<Result<Expense, ExpenseFailure>> call(Expense expense) async {
    switch (_validate(expense)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final valid):
        final saved = await _repository.update(valid);
        return saved.map((_) => valid);
    }
  }
}
