import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/data/repositories/budget_repository_impl.dart';
import 'package:mizan/features/budget/data/repositories/income_source_repository_impl.dart';
import 'package:mizan/features/budget/domain/entities/budget.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_error.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';

import '../../../../support/test_database.dart';

const _tnd = Currency.tnd;

void main() {
  late AppDatabase db;
  late IncomeSourceRepositoryImpl incomes;
  late BudgetRepositoryImpl budgets;

  setUp(() {
    db = openTestDatabase();
    incomes = IncomeSourceRepositoryImpl(db.incomeSourcesDao);
    budgets = BudgetRepositoryImpl(db.budgetsDao, currency: _tnd);
  });
  tearDown(() => db.close());

  group('income sources', () {
    final sources = [
      const IncomeSource(
        id: 's1',
        name: 'Grant',
        amount: Money(450000, _tnd),
        schedule: IncomeSchedule.monthly(dayOfMonth: 31),
      ),
      IncomeSource(
        id: 's2',
        name: 'Birthday',
        amount: const Money(50000, _tnd),
        schedule: IncomeSchedule.oneOff(date: DateTime.utc(2026, 10, 20)),
      ),
      const IncomeSource(
        id: 's3',
        name: 'Tutoring',
        amount: Money(120000, _tnd),
        schedule: IncomeSchedule.irregular(),
      ),
    ];

    Future<List<IncomeSource>> all() async =>
        (await incomes.watchAll().first).valueOrNull!;

    test('every schedule reads back identically', () async {
      for (final source in sources) {
        expect((await incomes.add(source)).isOk, isTrue);
      }

      expect(await all(), unorderedEquals(sources));
    });

    test('update and delete', () async {
      await incomes.add(sources[0]);
      final changed = sources[0].copyWith(
        schedule: const IncomeSchedule.irregular(),
      );

      expect((await incomes.update(changed)).isOk, isTrue);
      expect(await all(), [changed]);

      expect((await incomes.delete('s1')).isOk, isTrue);
      expect(await all(), isEmpty);
    });

    test('missing sources: notFound', () async {
      expect(
        (await incomes.update(sources[0])).failureOrNull?.error,
        BudgetError.notFound,
      );
      expect(
        (await incomes.delete('s1')).failureOrNull?.error,
        BudgetError.notFound,
      );
    });

    test('a database error: storage', () async {
      await incomes.add(sources[0]);
      expect(
        (await incomes.add(sources[0])).failureOrNull?.error,
        BudgetError.storage,
      );
    });

    test('an unreadable schedule: the stream emits storage', () async {
      await incomes.add(sources[2]);
      await (db.update(db.incomeSources)..where((s) => s.id.equals('s3')))
          .write(const IncomeSourcesCompanion(scheduleType: Value('weekly')));

      final result = await incomes.watchAll().first;

      expect(result.failureOrNull?.error, BudgetError.storage);
    });
  });

  group('budgets', () {
    Future<List<Budget>> all() async =>
        (await budgets.watchAll().first).valueOrNull!;

    test('saves and reads back, with and without a limit', () async {
      const october = Budget(
        id: 'budget-2026-10',
        month: YearMonth(2026, 10),
        totalLimit: Money(600000, _tnd),
      );
      const december = Budget(id: 'budget-2026-12', month: YearMonth(2026, 12));

      await budgets.save(october);
      await budgets.save(december);

      expect(await all(), unorderedEquals([october, december]));
      final row = (await db.budgetsDao.findById('budget-2026-12'))!;
      expect(row.currency, 'TND');
    });

    test('saving a month again replaces its budget', () async {
      const month = YearMonth(2026, 10);
      await budgets.save(
        const Budget(
          id: 'budget-2026-10',
          month: month,
          totalLimit: Money(1, _tnd),
        ),
      );
      await budgets.save(
        const Budget(
          id: 'budget-2026-10',
          month: month,
          totalLimit: Money(2, _tnd),
        ),
      );

      expect((await all()).single.totalLimit, const Money(2, _tnd));
    });

    test('an unreadable month: the stream emits storage', () async {
      await budgets.save(
        const Budget(id: 'budget-2026-10', month: YearMonth(2026, 10)),
      );
      await (db.update(db.budgets)..where((b) => b.id.equals('budget-2026-10')))
          .write(const BudgetsCompanion(month: Value('2026-13')));

      final result = await budgets.watchAll().first;

      expect(result.failureOrNull?.error, BudgetError.storage);
    });
  });
}
