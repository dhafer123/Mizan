import '../../../../core/result/result.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';
import '../value_objects/category_error.dart';
import '../value_objects/category_failure.dart';

/// Hides a category from pickers. Nothing is deleted: its expenses keep
/// their category, and `RestoreCategory` brings it back. The last active
/// category can't be archived, so there is always one to file expenses under.
class ArchiveCategory {
  const ArchiveCategory(this._repository);

  final CategoryRepository _repository;

  Future<Result<Category, CategoryFailure>> call(String id) async {
    final all = await _repository.getAll();
    if (all case Err(:final failure)) return Err(failure);
    final categories = all.valueOrNull!;

    final current = categories.where((c) => c.id == id).firstOrNull;
    if (current == null) {
      return const Err(CategoryFailure(CategoryError.notFound));
    }
    if (current.archived) return Ok(current);
    if (categories.where((c) => !c.archived).length == 1) {
      return const Err(CategoryFailure(CategoryError.lastActive));
    }

    final archived = current.copyWith(archived: true);
    final saved = await _repository.update(archived);
    return saved.map((_) => archived);
  }
}
