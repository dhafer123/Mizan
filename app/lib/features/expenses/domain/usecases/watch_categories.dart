import '../../../../core/result/result.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';
import '../value_objects/expense_failure.dart';

/// Every category, archived ones included (old expenses still need their
/// name and icon). Pickers show only the active ones.
class WatchCategories {
  const WatchCategories(this._repository);

  final CategoryRepository _repository;

  Stream<Result<List<Category>, ExpenseFailure>> call() =>
      _repository.watchAll();
}
