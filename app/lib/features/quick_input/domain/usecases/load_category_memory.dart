import '../../../../core/result/result.dart';
import '../../../expenses/domain/repositories/expense_repository.dart';
import '../../../expenses/domain/value_objects/expense_failure.dart';
import '../value_objects/category_memory.dart';
import 'learn_categories.dart';

/// Reads the user's expenses and learns their categories, for the
/// confirmation sheet's suggestions.
class LoadCategoryMemory {
  const LoadCategoryMemory(
    this._expenses, {
    LearnCategories learn = const LearnCategories(),
  }) : _learn = learn;

  final ExpenseRepository _expenses;
  final LearnCategories _learn;

  Future<Result<CategoryMemory, ExpenseFailure>> call() async =>
      switch (await _expenses.getAll()) {
        Ok(:final value) => Ok(_learn(value)),
        Err(:final failure) => Err(failure),
      };
}
