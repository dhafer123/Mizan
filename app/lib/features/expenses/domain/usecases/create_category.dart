import '../../../../core/ids/id_generator.dart';
import '../../../../core/money/money.dart';
import '../../../../core/result/result.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';
import '../value_objects/category_failure.dart';
import 'validate_category.dart';

/// Adds a custom category. Returns it as saved.
class CreateCategory {
  const CreateCategory(this._repository, this._ids, this._validate);

  final CategoryRepository _repository;
  final IdGenerator _ids;
  final ValidateCategory _validate;

  Future<Result<Category, CategoryFailure>> call({
    required String name,
    required String icon,
    Money? monthlyLimit,
  }) async {
    final all = await _repository.getAll();
    if (all case Err(:final failure)) return Err(failure);

    final validated = _validate(
      Category(
        id: _ids.newId(),
        name: name,
        icon: icon,
        monthlyLimit: monthlyLimit,
      ),
      others: all.valueOrNull!,
    );
    switch (validated) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final category):
        final saved = await _repository.add(category);
        return saved.map((_) => category);
    }
  }
}
