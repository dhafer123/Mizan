import 'dart:math';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/core/clock/calendar_day.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/ids/uuid_v7_generator.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/data/repositories/budget_repository_impl.dart';
import 'package:mizan/features/budget/domain/usecases/set_monthly_budget.dart';
import 'package:mizan/features/expenses/data/mappers/expense_mapper.dart';
import 'package:mizan/features/expenses/data/repositories/category_repository_impl.dart';
import 'package:mizan/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mizan/features/expenses/domain/usecases/add_expense.dart';
import 'package:mizan/features/expenses/domain/usecases/archive_category.dart';
import 'package:mizan/features/expenses/domain/usecases/delete_expense.dart';
import 'package:mizan/features/expenses/domain/usecases/edit_category.dart';
import 'package:mizan/features/expenses/domain/usecases/edit_expense.dart';
import 'package:mizan/features/expenses/domain/usecases/validate_category.dart';
import 'package:mizan/features/expenses/domain/usecases/validate_expense.dart';
import 'package:mizan/features/sync/data/remote/sync_api.dart';
import 'package:mizan/features/sync/data/repositories/sync_repository_impl.dart';

import '../support/test_database.dart';
import 'sim_network.dart';

/// A simulated phone: the app's real database, DAOs, use cases and sync
/// repository, on a [SimLink] to the server. Only time and the network are
/// fake.
class SimDevice {
  SimDevice(
    this.name,
    SimBackend backend,
    this.random, {
    required String baseUrl,
    Map<String, String> headers = const {},
  }) : link = SimLink(backend, random) {
    final ids = UuidV7Generator(clock, random: Random(random.nextInt(1 << 32)));
    db = AppDatabase(NativeDatabase.memory(), ids: ids, clock: clock);
    deviceId = ids.newId();
    final dio = Dio(BaseOptions(baseUrl: baseUrl, headers: headers))
      ..httpClientAdapter = link;
    sync = SyncRepositoryImpl(
      db: db,
      api: SyncApi(dio),
      clock: clock,
      deviceId: () async => deviceId,
      signedIn: () async => true,
    );
    final expenses = ExpenseRepositoryImpl(db.expensesDao);
    final categories = CategoryRepositoryImpl(
      db.categoriesDao,
      currency: Currency.tnd,
    );
    final validateExpense = ValidateExpense(clock);
    addExpense = AddExpense(expenses, ids, validateExpense);
    editExpense = EditExpense(expenses, validateExpense);
    deleteExpense = DeleteExpense(expenses);
    editCategory = EditCategory(categories, const ValidateCategory());
    archiveCategory = ArchiveCategory(categories);
    categoryRepository = categories;
    setBudget = SetMonthlyBudget(
      BudgetRepositoryImpl(db.budgetsDao, currency: Currency.tnd),
    );
  }

  final String name;
  final Random random;
  final SimLink link;
  final clock = FakeClock(testNow);
  late final AppDatabase db;
  late final String deviceId;
  late final SyncRepositoryImpl sync;
  late final AddExpense addExpense;
  late final EditExpense editExpense;
  late final DeleteExpense deleteExpense;
  late final EditCategory editCategory;
  late final ArchiveCategory archiveCategory;
  late final CategoryRepositoryImpl categoryRepository;
  late final SetMonthlyBudget setBudget;

  /// Every op this phone ever queued, by op id (outbox snapshots: an op
  /// stays in the outbox until the server takes it, so none are missed).
  final queued = <String, OutboxEntry>{};

  Future<void> rememberOutbox() async {
    for (final op in await db.select(db.outbox).get()) {
      queued.putIfAbsent(op.opId, () => op);
    }
  }

  Future<void> close() => db.close();

  // --- Random edits, through the app's use cases ---

  static const _notes = [null, 'coffee', 'taxi', 'rent share', 'books'];
  static const _names = ['Groceries', 'Bus', 'Housing', 'Uni', 'Fun', 'Misc'];

  Future<String> randomEdit() async {
    final live = await db.expensesDao.getLive();
    final roll = random.nextInt(100);
    if (roll < 35 || live.isEmpty) return _add();
    if (roll < 60) return _edit(live[random.nextInt(live.length)]);
    if (roll < 72) return _delete(live[random.nextInt(live.length)]);
    if (roll < 86) return _renameCategory();
    if (roll < 92) return _archiveCategory();
    return _budget();
  }

  Future<String> _add() async {
    final categories = (await categoryRepository.getAll()).valueOrNull!
        .where((c) => !c.archived)
        .toList();
    final result = await addExpense(
      amount: Money(100 + random.nextInt(50000), Currency.tnd),
      categoryId: categories[random.nextInt(categories.length)].id,
      date: clock.now().calendarDay.subtract(
        Duration(days: random.nextInt(40)),
      ),
      note: _notes[random.nextInt(_notes.length)],
    );
    return 'add ${result.valueOrNull?.id ?? result.failureOrNull}';
  }

  Future<String> _edit(ExpenseRow row) async {
    final expense = ExpenseMapper.toDomain(row);
    final edited = switch (random.nextInt(3)) {
      0 => expense.copyWith(
        amount: Money(100 + random.nextInt(50000), Currency.tnd),
      ),
      1 => expense.copyWith(note: _notes[random.nextInt(_notes.length)]),
      _ => expense.copyWith(
        amount: Money(100 + random.nextInt(50000), Currency.tnd),
        note: 'both',
      ),
    };
    final result = await editExpense(edited);
    return 'edit ${row.id} ${result.isOk ? 'ok' : result.failureOrNull}';
  }

  Future<String> _delete(ExpenseRow row) async {
    final result = await deleteExpense(row.id);
    return 'delete ${row.id} ${result.isOk ? 'ok' : result.failureOrNull}';
  }

  Future<String> _renameCategory() async {
    final all = (await categoryRepository.getAll()).valueOrNull!;
    final category = all[random.nextInt(all.length)];
    final newName = '${_names[random.nextInt(_names.length)]} $name';
    final limit = random.nextBool()
        ? null
        : Money(1000 + random.nextInt(100000), Currency.tnd);
    final result = await editCategory(
      category.copyWith(name: newName, monthlyLimit: limit),
    );
    return 'rename ${category.id} ${result.isOk ? 'ok' : result.failureOrNull}';
  }

  Future<String> _archiveCategory() async {
    final all = (await categoryRepository.getAll()).valueOrNull!
        .where((c) => !c.archived)
        .toList();
    final category = all[random.nextInt(all.length)];
    final result = await archiveCategory(category.id);
    return 'archive ${category.id} ${result.isOk ? 'ok' : result.failureOrNull}';
  }

  Future<String> _budget() async {
    final month = YearMonth(2026, 9 + random.nextInt(3));
    final limit = random.nextInt(4) == 0
        ? null
        : Money(100000 + random.nextInt(900000), Currency.tnd);
    final result = await setBudget(month, totalLimit: limit);
    return 'budget $month ${result.isOk ? 'ok' : result.failureOrNull}';
  }
}
