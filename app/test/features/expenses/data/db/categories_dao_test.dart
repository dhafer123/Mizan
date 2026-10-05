import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/features/sync/data/db/outbox_op_type.dart';

import '../../../../support/sequential_id_generator.dart';
import '../../../../support/test_database.dart';

CategoryRow _row({
  String id = 'c1',
  String name = 'Gym',
  String icon = 'sport',
  int? limit,
  bool archived = false,
}) => CategoryRow(
  id: id,
  name: name,
  icon: icon,
  monthlyLimitMinor: limit,
  currency: 'TND',
  archived: archived,
  version: 0,
  deleted: false,
);

/// The built-in "Food" default, as a row.
final _food = _row(id: 'food', name: 'Food', icon: 'food');

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<List<OutboxEntry>> outbox() => db.select(db.outbox).get();

  Map<String, Object?> fields(OutboxEntry op) =>
      jsonDecode(op.changedFields) as Map<String, Object?>;

  test('insert stores the row and queues a create with every field', () async {
    await db.categoriesDao.insertCategory(_row(limit: 30000));

    expect(await db.categoriesDao.findById('c1'), _row(limit: 30000));
    final [op] = await outbox();
    expect(op.entity, 'categories');
    expect(op.opType, OutboxOpType.create);
    expect(fields(op), {
      'id': 'c1',
      'name': 'Gym',
      'icon': 'sport',
      'monthlyLimitMinor': 30000,
      'currency': 'TND',
      'archived': false,
    });
  });

  group('update of a stored category', () {
    test('queues only the changed fields, at the stored version', () async {
      await db.categoriesDao.insertCategory(_row());
      await (db.update(db.categories)..where((c) => c.id.equals('c1'))).write(
        const CategoriesCompanion(version: Value(4), serverSeq: Value(40)),
      );

      final changed = await db.categoriesDao.updateCategory(
        _row(name: 'Fitness', archived: true),
      );

      expect(changed, isTrue);
      final row = (await db.categoriesDao.findById('c1'))!;
      expect(row.name, 'Fitness');
      expect(row.archived, isTrue);
      expect(row.version, 4);
      expect(row.serverSeq, 40);
      final [_, op] = await outbox();
      expect(op.opType, OutboxOpType.update);
      expect(op.baseVersion, 4);
      expect(fields(op), {'name': 'Fitness', 'archived': true});
    });

    test('does nothing when nothing changed', () async {
      await db.categoriesDao.insertCategory(_row());

      expect(await db.categoriesDao.updateCategory(_row()), isFalse);
      expect(await outbox(), hasLength(1));
    });
  });

  group('first change to a built-in default', () {
    test('stores the row and queues an update at version 0', () async {
      final changed = await db.categoriesDao.updateCategory(
        _food.copyWith(name: 'Eating out'),
        builtIn: _food,
      );

      expect(changed, isTrue);
      expect(
        await db.categoriesDao.findById('food'),
        _food.copyWith(name: 'Eating out'),
      );
      final [op] = await outbox();
      expect(op.opType, OutboxOpType.update);
      expect(op.entityId, 'food');
      expect(op.baseVersion, 0);
      expect(fields(op), {'name': 'Eating out'});
    });

    test('later changes update the stored row, not the default', () async {
      await db.categoriesDao.updateCategory(
        _food.copyWith(name: 'Eating out'),
        builtIn: _food,
      );

      await db.categoriesDao.updateCategory(
        _food.copyWith(name: 'Eating out', archived: true),
        builtIn: _food,
      );

      final [_, op] = await outbox();
      expect(fields(op), {'archived': true});
    });

    test('an unchanged default stores nothing', () async {
      expect(
        await db.categoriesDao.updateCategory(_food, builtIn: _food),
        isFalse,
      );
      expect(await db.categoriesDao.findById('food'), isNull);
      expect(await outbox(), isEmpty);
    });
  });

  test('an unknown id without a default is refused', () async {
    await expectLater(
      db.categoriesDao.updateCategory(_row(id: 'nope')),
      throwsStateError,
    );
    expect(await outbox(), isEmpty);
  });

  test('watchLive includes archived rows', () async {
    await db.categoriesDao.insertCategory(_row(archived: true));

    expect(await db.categoriesDao.watchLive().first, [_row(archived: true)]);
  });

  group('the write and its outbox op are one transaction', () {
    test('a failed outbox append leaves no default override', () async {
      await db.close();
      db = openTestDatabase(ids: SequentialIdGenerator(ids: ['dup', 'dup']));
      await db.categoriesDao.insertCategory(_row());

      await expectLater(
        db.categoriesDao.updateCategory(
          _food.copyWith(name: 'Eating out'),
          builtIn: _food,
        ),
        throwsA(anything),
      );

      expect(await db.categoriesDao.findById('food'), isNull);
      expect(await outbox(), hasLength(1));
    });

    test('a failed outbox append leaves the stored row as it was', () async {
      await db.close();
      db = openTestDatabase(ids: SequentialIdGenerator(ids: ['dup', 'dup']));
      await db.categoriesDao.insertCategory(_row());

      await expectLater(
        db.categoriesDao.updateCategory(_row(name: 'Fitness')),
        throwsA(anything),
      );

      expect((await db.categoriesDao.findById('c1'))!.name, 'Gym');
    });
  });
}
