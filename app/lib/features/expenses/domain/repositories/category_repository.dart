import '../../../../core/result/result.dart';
import '../entities/category.dart';
import '../value_objects/category_failure.dart';

/// Categories on this device: the built-in defaults plus stored ones. Every
/// write is also queued for sync.
abstract interface class CategoryRepository {
  /// Every category, archived ones included, re-emitted on every change:
  /// the defaults first, in their fixed order, then the custom ones by name.
  Stream<Result<List<Category>, CategoryFailure>> watchAll();

  /// The same list as [watchAll], read once.
  Future<Result<List<Category>, CategoryFailure>> getAll();

  /// Stores a new custom category.
  Future<Result<void, CategoryFailure>> add(Category category);

  /// Saves changes to a stored category or to a built-in default. Fails with
  /// `notFound` for any other id.
  Future<Result<void, CategoryFailure>> update(Category category);
}
