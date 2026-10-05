import '../../../../core/result/result.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';
import '../value_objects/category_error.dart';
import '../value_objects/category_failure.dart';
import 'validate_category.dart';

/// Brings an archived category back to the pickers. Fails with `nameTaken`
/// if an active category took its name meanwhile (rename one of them first).
class RestoreCategory {
  const RestoreCategory(this._repository, this._validate);

  final CategoryRepository _repository;
  final ValidateCategory _validate;

  Future<Result<Category, CategoryFailure>> call(String id) async {
    final all = await _repository.getAll();
    if (all case Err(:final failure)) return Err(failure);
    final categories = all.valueOrNull!;

    final current = categories.where((c) => c.id == id).firstOrNull;
    if (current == null) {
      return const Err(CategoryFailure(CategoryError.notFound));
    }
    if (!current.archived) return Ok(current);

    final validated = _validate(
      current.copyWith(archived: false),
      others: categories,
    );
    switch (validated) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final restored):
        final saved = await _repository.update(restored);
        return saved.map((_) => restored);
    }
  }
}
