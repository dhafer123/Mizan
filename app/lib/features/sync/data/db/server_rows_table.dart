import 'package:drift/drift.dart';

/// Each synced row as the server last sent it, before local changes still
/// queued are laid on top. The row the app shows is always this plus the
/// queue (`rebaseRow`), so when a queued op leaves the outbox (accepted or
/// refused) the row is rebuilt from here, never left with stale local
/// values (ADR 0007).
@DataClassName('ServerRow')
class ServerRows extends Table {
  /// Synced table name, e.g. `expenses`. Also kept for entities this app
  /// version has no table for yet (group data until week 4).
  TextColumn get entity => text()();
  TextColumn get entityId => text()();

  /// The server's state, as sync JSON.
  TextColumn get state => text()();
  IntColumn get serverSeq => integer()();

  @override
  Set<Column<Object>> get primaryKey => {entity, entityId};
}
