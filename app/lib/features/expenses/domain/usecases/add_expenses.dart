import '../../../../core/ids/id_generator.dart';
import '../../../../core/money/money.dart';
import '../../../../core/result/result.dart';
import '../entities/expense.dart';
import '../repositories/expense_repository.dart';
import '../value_objects/expense_failure.dart';
import '../value_objects/expense_item_failure.dart';
import '../value_objects/expense_source.dart';
import 'validate_expense.dart';

/// One expense to add with [AddExpenses].
typedef NewExpense = ({
  Money amount,
  String categoryId,
  DateTime date,
  String? note,
});

/// Records several personal expenses at once, all or none: the confirmed
/// items of a quick input. Every one is validated before anything is
/// written. Returns them as saved, in order.
class AddExpenses {
  const AddExpenses(this._repository, this._ids, this._validate);

  final ExpenseRepository _repository;
  final IdGenerator _ids;
  final ValidateExpense _validate;

  /// A validation failure is an [ExpenseItemFailure] naming the expense.
  Future<Result<List<Expense>, ExpenseFailure>> call(
    List<NewExpense> expenses, {
    required ExpenseSource source,
  }) async {
    final valid = <Expense>[];
    for (final (i, e) in expenses.indexed) {
      final checked = _validate(
        Expense(
          id: _ids.newId(),
          amount: e.amount,
          categoryId: e.categoryId,
          date: e.date,
          note: e.note,
          source: source,
        ),
      );
      switch (checked) {
        case Err(:final failure):
          return Err(ExpenseItemFailure(i, failure.error));
        case Ok(:final value):
          valid.add(value);
      }
    }
    if (valid.isEmpty) return const Ok([]);
    return switch (await _repository.addAll(valid)) {
      Ok() => Ok(valid),
      Err(:final failure) => Err(failure),
    };
  }
}
