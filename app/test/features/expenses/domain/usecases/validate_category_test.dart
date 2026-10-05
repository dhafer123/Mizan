import 'package:glados/glados.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/usecases/validate_category.dart';
import 'package:mizan/features/expenses/domain/value_objects/category_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/category_failure.dart';

const _validate = ValidateCategory();

Category _category({
  String id = 'c1',
  String name = 'Gym',
  String icon = 'sport',
  Money? limit,
  bool archived = false,
}) => Category(
  id: id,
  name: name,
  icon: icon,
  monthlyLimit: limit,
  archived: archived,
);

CategoryError? _errorOf(
  Category category, {
  List<Category> others = DefaultCategories.all,
}) => _validate(category, others: others).failureOrNull?.error;

void main() {
  test('accepts a valid category, name trimmed', () {
    expect(
      _validate(_category(name: '  Gym '), others: DefaultCategories.all),
      Ok<Category, CategoryFailure>(_category()),
    );
  });

  group('name', () {
    test('is required', () {
      expect(_errorOf(_category(name: '')), CategoryError.nameEmpty);
      expect(_errorOf(_category(name: '   ')), CategoryError.nameEmpty);
    });

    test('has a maximum length, counted after trimming', () {
      final longest = 'x' * ValidateCategory.maxNameLength;
      expect(_errorOf(_category(name: ' $longest ')), isNull);
      expect(
        _errorOf(_category(name: '${longest}x')),
        CategoryError.nameTooLong,
      );
    });

    test('must differ from other active categories, ignoring case', () {
      expect(_errorOf(_category(name: 'food')), CategoryError.nameTaken);
      expect(_errorOf(_category(name: ' FOOD ')), CategoryError.nameTaken);
    });

    test('may keep its own name', () {
      expect(_errorOf(DefaultCategories.food.copyWith(name: 'Food')), isNull);
    });

    test('may reuse the name of an archived category', () {
      final others = [
        ...DefaultCategories.all,
        _category(id: 'old', name: 'Gym', archived: true),
      ];
      expect(_errorOf(_category(), others: others), isNull);
    });

    test('is not checked for a category being archived', () {
      final others = [...DefaultCategories.all, _category(id: 'c2')];
      expect(_errorOf(_category(archived: true), others: others), isNull);
    });
  });

  test('icon is required', () {
    expect(_errorOf(_category(icon: '')), CategoryError.noIcon);
  });

  test('limit is optional, but more than zero when set', () {
    expect(_errorOf(_category()), isNull);
    expect(_errorOf(_category(limit: const Money(1, Currency.tnd))), isNull);
    expect(
      _errorOf(_category(limit: const Money(0, Currency.tnd))),
      CategoryError.limitNotPositive,
    );
    expect(
      _errorOf(_category(limit: const Money(-5, Currency.tnd))),
      CategoryError.limitNotPositive,
    );
  });

  test('every error has a message for the UI', () {
    for (final error in CategoryError.values) {
      expect(CategoryFailure(error).message, isNotEmpty);
    }
  });

  Glados(any.letterOrDigits).test(
    'an accepted name is trimmed, non-empty, short enough and unique',
    (raw) {
      final name = '  $raw ';
      final result = _validate(
        _category(name: name),
        others: DefaultCategories.all,
      );
      switch (result) {
        case Ok(value: final category):
          expect(category.name, raw.trim());
          expect(category.name, isNotEmpty);
          expect(
            category.name.length,
            lessThanOrEqualTo(ValidateCategory.maxNameLength),
          );
          expect(
            DefaultCategories.all.map((c) => c.name.toLowerCase()),
            isNot(contains(category.name.toLowerCase())),
          );
        case Err(:final failure):
          expect(
            failure.error,
            isIn([
              CategoryError.nameEmpty,
              CategoryError.nameTooLong,
              CategoryError.nameTaken,
            ]),
          );
      }
    },
  );
}
