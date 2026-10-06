import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/clock/clock.dart';
import '../../core/ids/id_generator.dart';
import '../../features/budget/data/db/budget_category_limits_table.dart';
import '../../features/budget/data/db/budgets_dao.dart';
import '../../features/budget/data/db/budgets_table.dart';
import '../../features/budget/data/db/income_sources_dao.dart';
import '../../features/budget/data/db/income_sources_table.dart';
import '../../features/expenses/data/db/categories_dao.dart';
import '../../features/expenses/data/db/categories_table.dart';
import '../../features/expenses/data/db/expenses_dao.dart';
import '../../features/expenses/data/db/expenses_table.dart';
import '../../features/groups/data/db/group_backfills_table.dart';
import '../../features/groups/data/db/groups_dao.dart';
import '../../features/groups/data/db/groups_table.dart';
import '../../features/groups/data/db/members_table.dart';
import '../../features/groups/data/db/settlements_dao.dart';
import '../../features/groups/data/db/settlements_table.dart';
import '../../features/groups/data/db/shared_expenses_dao.dart';
import '../../features/groups/data/db/shared_expenses_table.dart';
import '../../features/sync/data/db/entity_history_table.dart';
import '../../features/sync/data/db/outbox_dao.dart';
import '../../features/sync/data/db/outbox_op_type.dart';
import '../../features/sync/data/db/outbox_status.dart';
import '../../features/sync/data/db/outbox_table.dart';
import '../../features/sync/data/db/server_rows_table.dart';
import '../../features/sync/data/db/sync_state_dao.dart';
import '../../features/sync/data/db/sync_state_table.dart';
import 'app_database.steps.dart';

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
    ServerRows,
    Groups,
    Members,
    GroupBackfills,
    SharedExpenses,
    Settlements,
  ],
  daos: [
    ExpensesDao,
    CategoriesDao,
    IncomeSourcesDao,
    BudgetsDao,
    OutboxDao,
    SyncStateDao,
    GroupsDao,
    SharedExpensesDao,
    SettlementsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor, {required this.ids, required this.clock});

  /// The on-device database file, opened in a background isolate. Shared
  /// across isolates, so background sync (WorkManager) and the app use one
  /// connection instead of two writers.
  factory AppDatabase.open({required IdGenerator ids, required Clock clock}) =>
      AppDatabase(
        driftDatabase(
          name: 'mizan',
          native: const DriftNativeOptions(shareAcrossIsolates: true),
        ),
        ids: ids,
        clock: clock,
      );

  /// Generates outbox op ids.
  final IdGenerator ids;

  /// Timestamps outbox ops.
  final Clock clock;

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(
      // 3.6: sync client. The cursor stays: nothing was pulled before v2.
      from1To2: (m, schema) async {
        await m.addColumn(schema.syncState, schema.syncState.accountId);
        await m.addColumn(schema.entityHistory, schema.entityHistory.kind);
        await m.addColumn(schema.outbox, schema.outbox.rejectReason);
      },
      // 3.7: shadow copies of server rows (rebuild after an op leaves the
      // queue). Existing rows have none yet; the next pull fills them.
      from2To3: (m, schema) async {
        await m.createTable(schema.serverRows);
      },
      // 4.1: groups and members. Their rows were pulled since 3.6 and kept
      // as shadows (ADR 0008), so build the tables from those: nothing
      // could queue an op for them before v4, so the shadow is the row.
      from3To4: (m, schema) async {
        await m.createTable(schema.groups);
        await m.createTable(schema.members);
        await m.createIndex(schema.membersGroup);
        await m.createTable(schema.groupBackfills);
        await customStatement('''
          INSERT INTO "groups"
            (id, name, currency, version, deleted, updated_by, server_seq)
          SELECT entity_id, json_extract(state, '\$.name'),
            json_extract(state, '\$.currency'),
            json_extract(state, '\$.version'),
            json_extract(state, '\$.deleted'),
            json_extract(state, '\$.updatedBy'), server_seq
          FROM server_rows WHERE entity = 'groups'
        ''');
        await customStatement('''
          INSERT INTO members (id, group_id, user_id, display_name, version,
            deleted, updated_by, server_seq)
          SELECT entity_id, json_extract(state, '\$.groupId'),
            json_extract(state, '\$.userId'),
            json_extract(state, '\$.displayName'),
            json_extract(state, '\$.version'),
            json_extract(state, '\$.deleted'),
            json_extract(state, '\$.updatedBy'), server_seq
          FROM server_rows WHERE entity = 'members'
        ''');
      },
      // 4.2: shared expenses, built from their shadows like v4. `split` and
      // `shares` are JSON objects in the shadow; json_extract returns them
      // as JSON text, which is how the columns store them.
      from4To5: (m, schema) async {
        await m.createTable(schema.sharedExpenses);
        await m.createIndex(schema.sharedExpensesGroup);
        await customStatement('''
          INSERT INTO shared_expenses (id, group_id, payer_id, amount_minor,
            currency, date, split, shares, category_id, version, deleted,
            updated_by, server_seq)
          SELECT entity_id, json_extract(state, '\$.groupId'),
            json_extract(state, '\$.payerId'),
            json_extract(state, '\$.amountMinor'),
            json_extract(state, '\$.currency'),
            json_extract(state, '\$.date'),
            json_extract(state, '\$.split'),
            json_extract(state, '\$.shares'),
            json_extract(state, '\$.categoryId'),
            json_extract(state, '\$.version'),
            json_extract(state, '\$.deleted'),
            json_extract(state, '\$.updatedBy'), server_seq
          FROM server_rows WHERE entity = 'shared_expenses'
        ''');
      },
      // 4.4: settlements, built from their shadows like v4 and v5.
      from5To6: (m, schema) async {
        await m.createTable(schema.settlements);
        await m.createIndex(schema.settlementsGroup);
        await customStatement('''
          INSERT INTO settlements (id, group_id, from_member_id, to_member_id,
            amount_minor, currency, date, reverses_id, version, deleted,
            updated_by, server_seq)
          SELECT entity_id, json_extract(state, '\$.groupId'),
            json_extract(state, '\$.fromMemberId'),
            json_extract(state, '\$.toMemberId'),
            json_extract(state, '\$.amountMinor'),
            json_extract(state, '\$.currency'),
            json_extract(state, '\$.date'),
            json_extract(state, '\$.reversesId'),
            json_extract(state, '\$.version'),
            json_extract(state, '\$.deleted'),
            json_extract(state, '\$.updatedBy'), server_seq
          FROM server_rows WHERE entity = 'settlements'
        ''');
      },
    ),
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
