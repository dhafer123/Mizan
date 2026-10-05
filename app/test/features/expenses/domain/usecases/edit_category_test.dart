import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/usecases/edit_category.dart';
import 'package:mizan/features/expenses/domain/usecases/validate_category.dart';
import 'package:mizan/features/expenses/domain/value_objects/category_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/category_failure.dart';
import 'package:test/test.dart';

import '../../../../support/fake_category_repository.dart';

void main() {
  late FakeCategoryRepository repository;
  late EditCategory editCategory;

  setUp(() {
    repository = FakeCategoryRepository();
    editCategory = EditCategory(repository, const ValidateCategory());
  });

  test('renames a default category', () async {
    final result = await editCategory(
      DefaultCategories.food.copyWith(name: ' Eating out '),
    );

    final expected = DefaultCategories.food.copyWith(name: 'Eating out');
    expect(result, Ok<Category, CategoryFailure>(expected));
    expect(repository.byId('food'), expected);
  });

  test('changes the icon and sets or clears the limit', () async {
    const limit = Money(150000, Currency.tnd);
    await editCategory(
      DefaultCategories.rent.copyWith(icon: 'bills', monthlyLimit: limit),
    );
    expect(repository.byId('rent').icon, 'bills');
    expect(repository.byId('rent').monthlyLimit, limit);

    await editCategory(repository.byId('rent').copyWith(monthlyLimit: null));
    expect(repository.byId('rent').monthlyLimit, isNull);
  });

  test('keeps the stored archived flag', () async {
    await editCategory(DefaultCategories.study.copyWith(archived: true));

    expect(repository.byId('study').archived, isFalse);
  });

  test('writes nothing when nothing changed', () async {
    final result = await editCategory(DefaultCategories.food);

    expect(result.isOk, isTrue);
    expect(repository.updates, isEmpty);
  });

  test('refuses an invalid change', () async {
    final result = await editCategory(
      DefaultCategories.food.copyWith(name: 'rent'),
    );

    expect(result.failureOrNull?.error, CategoryError.nameTaken);
    expect(repository.byId('food'), DefaultCategories.food);
  });

  test('fails for an unknown id', () async {
    final result = await editCategory(
      const Category(id: 'nope', name: 'Nope', icon: 'other'),
    );

    expect(result.failureOrNull?.error, CategoryError.notFound);
  });
}
