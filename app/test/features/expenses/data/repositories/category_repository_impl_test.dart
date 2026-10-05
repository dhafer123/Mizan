import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/expenses/data/repositories/category_repository_impl.dart';
import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_error.dart';

import '../../../../support/test_database.dart';

CategoryRow _row({
  required String id,
  required String name,
  String icon = 'other',
  int? limit,
  String currency = 'TND',
  bool archived = false,
  bool deleted = false,
}) => CategoryRow(
  id: id,
  name: name,
  icon: icon,
  monthlyLimitMinor: limit,
  currency: currency,
  archived: archived,
  version: 0,
  deleted: deleted,
);

void main() {
  late AppDatabase db;
  late CategoryRepositoryImpl repository;

  setUp(() {
    db = openTestDatabase();
    repository = CategoryRepositoryImpl(db.categoriesDao);
  });
  tearDown(() => db.close());

  Future<List<Category>> all() async =>
      (await repository.watchAll().first).valueOrNull!;

  // Rows are written directly: creating categories (with their outbox ops)
  // is task 2.3.
  Future<void> store(CategoryRow row) => db.into(db.categories).insert(row);

  test('a fresh install has the default categories', () async {
    expect(await all(), DefaultCategories.all);
  });

  test('a stored row replaces the default with its id, in place', () async {
    await store(
      _row(id: 'food', name: 'Eating out', icon: 'food', limit: 150000),
    );

    final categories = await all();

    expect(categories.map((c) => c.id), DefaultCategories.all.map((c) => c.id));
    expect(
      categories.first,
      const Category(
        id: 'food',
        name: 'Eating out',
        icon: 'food',
        monthlyLimit: Money(150000, Currency.tnd),
      ),
    );
  });

  test('custom categories follow the defaults, by name', () async {
    await store(_row(id: 'c2', name: 'Gym'));
    await store(_row(id: 'c1', name: 'Coffee', archived: true));
    await store(_row(id: 'c3', name: 'Gone', deleted: true));

    final categories = await all();

    expect(categories.skip(DefaultCategories.all.length).map((c) => c.name), [
      'Coffee',
      'Gym',
    ]);
    expect(categories.firstWhere((c) => c.id == 'c1').archived, isTrue);
  });

  test('an unreadable row: the stream emits storage, not an error', () async {
    await store(_row(id: 'c1', name: 'Coffee', limit: 1, currency: 'XXX'));

    final result = await repository.watchAll().first;

    expect(result.failureOrNull?.error, ExpenseError.storage);
  });
}
