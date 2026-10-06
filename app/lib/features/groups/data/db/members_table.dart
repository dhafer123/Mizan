import 'package:drift/drift.dart';

import '../../../sync/data/db/sync_columns.dart';

/// People in a group. [userId] is null for a placeholder nobody has claimed.
/// No foreign key to `groups`: rows arrive from the server in seq order, and
/// a member may come before its group.
@DataClassName('MemberRow')
@TableIndex(name: 'members_group', columns: {#groupId})
class Members extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get displayName => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
