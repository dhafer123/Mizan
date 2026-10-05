import 'package:drift/drift.dart';

import '../../../sync/data/db/sync_columns.dart';

/// Personal expenses. Money is stored as integer minor units plus currency.
@DataClassName('ExpenseRow')
@TableIndex(name: 'expenses_date', columns: {#date})
class Expenses extends Table with SyncColumns {
  TextColumn get id => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  TextColumn get categoryId => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();

  /// `manual`, `voice` or `receipt`.
  TextColumn get source => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
