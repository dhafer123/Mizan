import '../../../../core/result/result.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';
import '../value_objects/category_error.dart';
import '../value_objects/category_failure.dart';
import 'validate_category.dart';

/// Renames a category or changes its icon or limit, defaults included.
/// Whether it is archived stays as stored: that is `ArchiveCategory` and
/// `RestoreCategory`. Returns it as saved.
class EditCategory {
  const EditCategory(this._repository, this._validate);

  final CategoryRepository _repository;
  final ValidateCategory _validate;

  Future<Result<Category, CategoryFailure>> call(Category edited) async {
    final all = await _repository.getAll();
    if (all case Err(:final failure)) return Err(failure);
    final categories = all.valueOrNull!;

    final current = categories.where((c) => c.id == edited.id).firstOrNull;
    if (current == null) {
      return const Err(CategoryFailure(CategoryError.notFound));
    }

    final validated = _validate(
      edited.copyWith(archived: current.archived),
      others: categories,
    );
    switch (validated) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final category):
        if (category == current) return Ok(category);
        final saved = await _repository.update(category);
        return saved.map((_) => category);
    }
  }
}
