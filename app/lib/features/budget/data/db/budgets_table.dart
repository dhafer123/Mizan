import 'package:drift/drift.dart';

import '../../../sync/data/db/sync_columns.dart';

/// A month's overall spending limit. Per-category limits are in
/// `BudgetCategoryLimits`.
@DataClassName('BudgetRow')
class Budgets extends Table with SyncColumns {
  TextColumn get id => text()();

  /// `YYYY-MM`.
  TextColumn get month => text().withLength(min: 7, max: 7)();
  IntColumn get totalLimitMinor => integer().nullable()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
