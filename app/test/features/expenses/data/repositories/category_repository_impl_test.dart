import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/expenses/data/repositories/category_repository_impl.dart';
import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/value_objects/category_error.dart';

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
    repository = CategoryRepositoryImpl(
      db.categoriesDao,
      currency: Currency.tnd,
    );
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

    expect(result.failureOrNull?.error, CategoryError.storage);
  });

  test('getAll reads the same merged list once', () async {
    await store(_row(id: 'food', name: 'Eating out', icon: 'food'));
    await store(_row(id: 'c1', name: 'Gym'));

    expect((await repository.getAll()).valueOrNull, await all());
  });

  test('getAll turns an unreadable row into storage', () async {
    await store(_row(id: 'c1', name: 'Coffee', limit: 1, currency: 'XXX'));

    final result = await repository.getAll();

    expect(result.failureOrNull?.error, CategoryError.storage);
  });

  group('writes', () {
    test('add stores a custom category, after the defaults', () async {
      const gym = Category(
        id: 'c1',
        name: 'Gym',
        icon: 'sport',
        monthlyLimit: Money(30000, Currency.tnd),
      );

      expect((await repository.add(gym)).isOk, isTrue);

      expect(await all(), [...DefaultCategories.all, gym]);
    });

    test('a category without a limit is stored in the app currency', () async {
      await repository.add(
        const Category(id: 'c1', name: 'Gym', icon: 'sport'),
      );

      expect((await db.categoriesDao.findById('c1'))!.currency, 'TND');
    });

    test('update of a default overrides it in place', () async {
      final renamed = DefaultCategories.food.copyWith(name: 'Eating out');

      expect((await repository.update(renamed)).isOk, isTrue);

      expect((await all()).first, renamed);
      final [op] = await db.select(db.outbox).get();
      expect(op.baseVersion, 0);
    });

    test('update of a stored category saves it', () async {
      const gym = Category(id: 'c1', name: 'Gym', icon: 'sport');
      await repository.add(gym);

      await repository.update(gym.copyWith(archived: true));

      expect((await all()).last.archived, isTrue);
    });

    test('update of an unknown id: notFound', () async {
      final result = await repository.update(
        const Category(id: 'nope', name: 'Nope', icon: 'other'),
      );

      expect(result.failureOrNull?.error, CategoryError.notFound);
    });

    test('a database error: storage, nothing thrown', () async {
      const gym = Category(id: 'c1', name: 'Gym', icon: 'sport');
      await repository.add(gym);

      final duplicate = await repository.add(gym);

      expect(duplicate.failureOrNull?.error, CategoryError.storage);
    });
  });
}
