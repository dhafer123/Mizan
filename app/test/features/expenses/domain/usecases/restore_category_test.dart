import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/usecases/archive_category.dart';
import 'package:mizan/features/expenses/domain/usecases/restore_category.dart';
import 'package:mizan/features/expenses/domain/usecases/validate_category.dart';
import 'package:mizan/features/expenses/domain/value_objects/category_error.dart';
import 'package:test/test.dart';

import '../../../../support/fake_category_repository.dart';

void main() {
  late FakeCategoryRepository repository;
  late RestoreCategory restoreCategory;

  setUp(() {
    repository = FakeCategoryRepository();
    restoreCategory = RestoreCategory(repository, const ValidateCategory());
  });

  test('brings an archived category back as it was', () async {
    await ArchiveCategory(repository)('food');

    final result = await restoreCategory('food');

    expect(result.valueOrNull, DefaultCategories.food);
    expect(repository.byId('food'), DefaultCategories.food);
  });

  test('an active category stays as it is', () async {
    final result = await restoreCategory('food');

    expect(result.valueOrNull, DefaultCategories.food);
    expect(repository.updates, isEmpty);
  });

  test('fails if an active category took its name meanwhile', () async {
    repository.categories.add(
      const Category(id: 'c1', name: 'Food', icon: 'food', archived: true),
    );
    // "Food" (the default) is active, so the archived custom "Food" can't
    // come back under that name.

    final result = await restoreCategory('c1');

    expect(result.failureOrNull?.error, CategoryError.nameTaken);
    expect(repository.byId('c1').archived, isTrue);
  });

  test('fails for an unknown id', () async {
    final result = await restoreCategory('nope');
    expect(result.failureOrNull?.error, CategoryError.notFound);
  });
}
