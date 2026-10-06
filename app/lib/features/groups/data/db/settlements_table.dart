import 'package:drift/drift.dart';

import '../../../sync/data/db/sync_columns.dart';

/// Payments between members. Insert-only: never edited or deleted; a
/// mistake is undone by a reversing settlement ([reversesId]).
@DataClassName('SettlementRow')
@TableIndex(name: 'settlements_group', columns: {#groupId})
class Settlements extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get fromMemberId => text()();
  TextColumn get toMemberId => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  DateTimeColumn get date => dateTime()();
  TextColumn get reversesId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
