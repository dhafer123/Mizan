import 'package:drift/drift.dart';

/// Groups this account joined whose older rows haven't all been pulled yet.
///
/// Rows written before joining have seqs below the sync cursor, so the
/// normal pull never brings them. Each group here is pulled on its own
/// (`/sync/pull?group=`) from [cursor] until done, then removed.
@DataClassName('GroupBackfill')
class GroupBackfills extends Table {
  TextColumn get groupId => text()();
  IntColumn get cursor => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {groupId};
}
