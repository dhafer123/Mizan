import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_source.dart';
import 'package:mizan/features/sync/data/db/outbox_op_type.dart';

import '../../../../support/test_database.dart';

Expense _expense({
  String id = 'e1',
  int amount = 4500,
  DateTime? date,
  String? note,
}) => Expense(
  id: id,
  amount: Money(amount, Currency.tnd),
  categoryId: 'food',
  date: date ?? DateTime.utc(2026, 10, 6),
  note: note,
  source: ExpenseSource.receipt,
);

void main() {
  late AppDatabase db;
  late ExpenseRepositoryImpl repository;

  setUp(() {
    db = openTestDatabase();
    repository = ExpenseRepositoryImpl(db.expensesDao);
  });
  tearDown(() => db.close());

  Future<List<Expense>> month(YearMonth month) async =>
      (await repository.watchMonth(month).first).valueOrNull!;

  test('an added expense reads back identically and is queued', () async {
    final expense = _expense(note: 'groceries');

    expect((await repository.add(expense)).isOk, isTrue);

    expect(await month(const YearMonth(2026, 10)), [expense]);
    final [op] = await db.select(db.outbox).get();
    expect(op.opType, OutboxOpType.create);
    expect(jsonDecode(op.changedFields), containsPair('amountMinor', 4500));
  });

  test('a month holds exactly its own days', () async {
    await repository.add(
      _expense(id: 'sep30', date: DateTime.utc(2026, 9, 30)),
    );
    await repository.add(_expense(id: 'oct1', date: DateTime.utc(2026, 10)));
    await repository.add(
      _expense(id: 'oct31', date: DateTime.utc(2026, 10, 31)),
    );
    await repository.add(_expense(id: 'nov1', date: DateTime.utc(2026, 11)));

    final october = await month(const YearMonth(2026, 10));

    expect(october.map((e) => e.id), unorderedEquals(['oct1', 'oct31']));
  });

  test('update saves the changes and queues them', () async {
    await repository.add(_expense());

    final result = await repository.update(_expense(amount: 5000));

    expect(result.isOk, isTrue);
    expect(await month(const YearMonth(2026, 10)), [_expense(amount: 5000)]);
    expect(await db.select(db.outbox).get(), hasLength(2));
  });

  test('delete hides the expense but keeps a tombstone to sync', () async {
    await repository.add(_expense());

    expect((await repository.delete('e1')).isOk, isTrue);

    expect(await month(const YearMonth(2026, 10)), isEmpty);
    expect((await db.expensesDao.findById('e1'))!.deleted, isTrue);
    final [_, op] = await db.select(db.outbox).get();
    expect(op.opType, OutboxOpType.delete);
  });

  test('the month re-emits after each write', () async {
    final sizes = repository
        .watchMonth(const YearMonth(2026, 10))
        .map((r) => r.valueOrNull!.length)
        .take(3)
        .toList();

    await pumpEventQueue();
    await repository.add(_expense());
    await pumpEventQueue();
    await repository.delete('e1');

    expect(await sizes, [0, 1, 0]);
  });

  group('failures', () {
    test(
      'update and delete of a missing or deleted expense: notFound',
      () async {
        expect(
          (await repository.update(_expense())).failureOrNull?.error,
          ExpenseError.notFound,
        );
        expect(
          (await repository.delete('e1')).failureOrNull?.error,
          ExpenseError.notFound,
        );

        await repository.add(_expense());
        await repository.delete('e1');
        expect(
          (await repository.delete('e1')).failureOrNull?.error,
          ExpenseError.notFound,
        );
      },
    );

    test('a database error on write: storage, nothing thrown', () async {
      await repository.add(_expense());

      final duplicate = await repository.add(_expense());

      expect(duplicate.failureOrNull?.error, ExpenseError.storage);
    });

    test('an unreadable row: the stream emits storage, not an error', () async {
      await repository.add(_expense());
      await (db.update(db.expenses)..where((e) => e.id.equals('e1'))).write(
        const ExpensesCompanion(currency: Value('XXX')),
      );

      final result = await repository
          .watchMonth(const YearMonth(2026, 10))
          .first;

      expect(result.failureOrNull?.error, ExpenseError.storage);
    });
  });
}
