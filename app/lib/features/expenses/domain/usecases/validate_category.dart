import '../../../../core/result/result.dart';
import '../entities/category.dart';
import '../value_objects/category_error.dart';
import '../value_objects/category_failure.dart';

/// Checks a category against the others before it is saved, and returns it
/// with its name trimmed.
class ValidateCategory {
  const ValidateCategory();

  /// Matches the column length in the categories table.
  static const maxNameLength = 40;

  Result<Category, CategoryFailure> call(
    Category category, {
    required List<Category> others,
  }) {
    Err<Category, CategoryFailure> fail(CategoryError error) =>
        Err(CategoryFailure(error));

    final name = category.name.trim();
    if (name.isEmpty) return fail(CategoryError.nameEmpty);
    if (name.length > maxNameLength) return fail(CategoryError.nameTooLong);
    if (category.icon.trim().isEmpty) return fail(CategoryError.noIcon);
    if (category.monthlyLimit case final limit? when !limit.isPositive) {
      return fail(CategoryError.limitNotPositive);
    }

    // Only active categories reserve a name: an archived "Gym" doesn't block
    // a new one. An archived category is checked again when restored.
    if (!category.archived) {
      final key = name.toLowerCase();
      final taken = others.any(
        (c) =>
            c.id != category.id &&
            !c.archived &&
            c.name.trim().toLowerCase() == key,
      );
      if (taken) return fail(CategoryError.nameTaken);
    }

    return Ok(category.copyWith(name: name));
  }
}
