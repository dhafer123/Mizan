import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/usecases/create_category.dart';
import 'package:mizan/features/expenses/domain/usecases/validate_category.dart';
import 'package:mizan/features/expenses/domain/value_objects/category_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/category_failure.dart';
import 'package:test/test.dart';

import '../../../../support/fake_category_repository.dart';
import '../../../../support/sequential_id_generator.dart';

void main() {
  late FakeCategoryRepository repository;
  late CreateCategory createCategory;

  setUp(() {
    repository = FakeCategoryRepository();
    createCategory = CreateCategory(
      repository,
      SequentialIdGenerator(prefix: 'c'),
      const ValidateCategory(),
    );
  });

  test('saves a custom category with a fresh id and returns it', () async {
    final result = await createCategory(
      name: ' Gym ',
      icon: 'sport',
      monthlyLimit: const Money(30000, Currency.tnd),
    );

    const expected = Category(
      id: 'c1',
      name: 'Gym',
      icon: 'sport',
      monthlyLimit: Money(30000, Currency.tnd),
    );
    expect(result, const Ok<Category, CategoryFailure>(expected));
    expect(repository.categories, [...DefaultCategories.all, expected]);
  });

  test('saves nothing when invalid', () async {
    final result = await createCategory(name: 'Food', icon: 'food');

    expect(result.failureOrNull?.error, CategoryError.nameTaken);
    expect(repository.categories, DefaultCategories.all);
  });

  test('passes on a failure to read the others', () async {
    repository.failure = const CategoryFailure(CategoryError.storage);

    final result = await createCategory(name: 'Gym', icon: 'sport');

    expect(result.failureOrNull?.error, CategoryError.storage);
  });

  test('passes on a failure to save', () async {
    repository.writeFailure = const CategoryFailure(CategoryError.storage);

    final result = await createCategory(name: 'Gym', icon: 'sport');

    expect(result.failureOrNull?.error, CategoryError.storage);
  });
}
