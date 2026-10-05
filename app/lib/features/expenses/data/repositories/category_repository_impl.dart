import '../../../../app/db/app_database.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/result/result.dart';
import '../../../../core/result/storage_errors_as_failures.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/default_categories.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/value_objects/category_error.dart';
import '../../domain/value_objects/category_failure.dart';
import '../db/categories_dao.dart';
import '../mappers/category_mapper.dart';

/// The built-in defaults, with stored rows on top: a row with a default's id
/// replaces it in place, other rows follow by name. Database errors become
/// [CategoryFailure]s; nothing is thrown past this class.
class CategoryRepositoryImpl implements CategoryRepository {
  /// [currency] goes into rows of categories without a limit.
  const CategoryRepositoryImpl(this._dao, {required Currency currency})
    : _currency = currency;

  final CategoriesDao _dao;
  final Currency _currency;

  static const _storage = CategoryFailure(CategoryError.storage);

  @override
  Stream<Result<List<Category>, CategoryFailure>> watchAll() => _dao
      .watchLive()
      .map<Result<List<Category>, CategoryFailure>>((rows) => Ok(_merge(rows)))
      .transform(storageErrorsAsFailures(_storage));

  @override
  Future<Result<List<Category>, CategoryFailure>> getAll() async {
    try {
      return Ok(_merge(await _dao.getLive()));
    } on Object {
      return const Err(_storage);
    }
  }

  static List<Category> _merge(List<CategoryRow> rows) {
    final stored = {
      for (final row in rows) row.id: CategoryMapper.toDomain(row),
    };
    final defaults = [
      for (final category in DefaultCategories.all)
        stored.remove(category.id) ?? category,
    ];
    final custom = stored.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return [...defaults, ...custom];
  }

  @override
  Future<Result<void, CategoryFailure>> add(Category category) =>
      _guard(() => _dao.insertCategory(_row(category)));

  @override
  Future<Result<void, CategoryFailure>> update(Category category) {
    final builtIn = DefaultCategories.all
        .where((c) => c.id == category.id)
        .firstOrNull;
    return _guard(
      () => _dao.updateCategory(
        _row(category),
        builtIn: builtIn == null ? null : _row(builtIn),
      ),
    );
  }

  CategoryRow _row(Category category) =>
      CategoryMapper.toRow(category, currency: _currency);

  static Future<Result<void, CategoryFailure>> _guard(
    Future<Object?> Function() write,
  ) async {
    try {
      await write();
      return const Ok(null);
    } on StateError {
      // The DAO's "no live category with this id".
      return const Err(CategoryFailure(CategoryError.notFound));
    } on Object {
      return const Err(_storage);
    }
  }
}
