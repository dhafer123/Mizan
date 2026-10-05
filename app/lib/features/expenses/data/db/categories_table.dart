import 'package:drift/drift.dart';

import '../../../sync/data/db/sync_columns.dart';

/// Spending categories. Archived ones stay so their history keeps a name.
@DataClassName('CategoryRow')
class Categories extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get icon => text()();
  IntColumn get monthlyLimitMinor => integer().nullable()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
