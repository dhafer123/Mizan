import 'package:drift/drift.dart';

/// Field-level change log shown in the UI ("Ali changed amount 120 → 150"),
/// including edits that lost a conflict. Written from pulled server history.
@DataClassName('EntityHistoryRow')
@TableIndex(name: 'entity_history_entity', columns: {#entity, #entityId})
class EntityHistory extends Table {
  TextColumn get id => text()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get field => text()();

  /// JSON-encoded values; null when the field was unset.
  TextColumn get oldValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  TextColumn get changedBy => text().nullable()();
  IntColumn get serverSeq => integer().nullable()();
  DateTimeColumn get changedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
