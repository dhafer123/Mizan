import '../../../../core/result/result.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/default_categories.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/value_objects/expense_failure.dart';
import '../db/categories_dao.dart';
import '../mappers/category_mapper.dart';
import 'storage_errors_as_failures.dart';

/// The default categories, with stored rows on top: a row with a default's
/// id replaces it, other rows follow by name.
class CategoryRepositoryImpl implements CategoryRepository {
  const CategoryRepositoryImpl(this._dao);

  final CategoriesDao _dao;

  @override
  Stream<Result<List<Category>, ExpenseFailure>> watchAll() => _dao
      .watchLive()
      .map<Result<List<Category>, ExpenseFailure>>((rows) {
        final stored = {
          for (final row in rows) row.id: CategoryMapper.toDomain(row),
        };
        final defaults = [
          for (final category in DefaultCategories.all)
            stored.remove(category.id) ?? category,
        ];
        final custom = stored.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return Ok([...defaults, ...custom]);
      })
      .transform(storageErrorsAsFailures());
}
