import 'package:drift/drift.dart';

import '../../../sync/data/db/sync_columns.dart';

/// A category's limit within one month's budget.
@DataClassName('BudgetCategoryLimitRow')
class BudgetCategoryLimits extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get budgetId => text()();
  TextColumn get categoryId => text()();
  IntColumn get limitMinor => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
