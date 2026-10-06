import 'package:drift/drift.dart';

import '../../../sync/data/db/sync_columns.dart';

/// Shared-expense groups this account is in. One currency per group.
@DataClassName('GroupRow')
class Groups extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
