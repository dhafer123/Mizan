import '../../../../core/result/result.dart';
import '../entities/category.dart';
import '../value_objects/expense_failure.dart';

abstract interface class CategoryRepository {
  /// Every category, archived ones included, re-emitted on every change.
  Stream<Result<List<Category>, ExpenseFailure>> watchAll();
}
