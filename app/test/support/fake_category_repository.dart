import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/repositories/category_repository.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_failure.dart';

/// A [CategoryRepository] with a fixed list (the defaults unless given).
class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository([List<Category> categories = DefaultCategories.all])
    : categories = [...categories];

  /// Change before the first watch.
  final List<Category> categories;

  /// When set, [watchAll] emits this instead.
  ExpenseFailure? failure;

  @override
  Stream<Result<List<Category>, ExpenseFailure>> watchAll() =>
      Stream.value(switch (failure) {
        final failure? => Err(failure),
        null => Ok(categories),
      });
}
