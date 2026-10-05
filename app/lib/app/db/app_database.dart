import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/clock/clock.dart';
import '../../core/ids/id_generator.dart';
import '../../features/budget/data/db/budget_category_limits_table.dart';
import '../../features/budget/data/db/budgets_table.dart';
import '../../features/budget/data/db/income_sources_table.dart';
import '../../features/expenses/data/db/categories_dao.dart';
import '../../features/expenses/data/db/categories_table.dart';
import '../../features/expenses/data/db/expenses_dao.dart';
import '../../features/expenses/data/db/expenses_table.dart';
import '../../features/sync/data/db/entity_history_table.dart';
import '../../features/sync/data/db/outbox_dao.dart';
import '../../features/sync/data/db/outbox_op_type.dart';
import '../../features/sync/data/db/outbox_status.dart';
import '../../features/sync/data/db/outbox_table.dart';
import '../../features/sync/data/db/sync_state_dao.dart';
import '../../features/sync/data/db/sync_state_table.dart';

part 'app_database.g.dart';

/// The local SQLite database: the source of truth for the UI.
///
/// Schema changes: bump [schemaVersion], run
/// `dart run drift_dev make-migrations`, and add the step to [migration].
@DriftDatabase(
  tables: [
    Expenses,
    Categories,
    IncomeSources,
    Budgets,
    BudgetCategoryLimits,
    Outbox,
    SyncState,
    EntityHistory,
  ],
  daos: [ExpensesDao, CategoriesDao, OutboxDao, SyncStateDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor, {required this.ids, required this.clock});

  /// The on-device database file, opened in a background isolate.
  factory AppDatabase.open({required IdGenerator ids, required Clock clock}) =>
      AppDatabase(
        driftDatabase(name: 'mizan'),
        ids: ids,
        clock: clock,
      );

  /// Generates outbox op ids.
  final IdGenerator ids;

  /// Timestamps outbox ops.
  final Clock clock;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
