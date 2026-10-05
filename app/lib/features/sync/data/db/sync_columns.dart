import 'package:drift/drift.dart';

/// Sync metadata carried by every synced table (ARCHITECTURE.md §4, §6).
///
/// Local writes never change [version] or [serverSeq]: the server sets them
/// when it applies an op, and pull brings them back.
mixin SyncColumns on Table {
  /// Server version this row is based on. 0 until the server first accepts it.
  IntColumn get version => integer().withDefault(const Constant(0))();

  /// Tombstone: deleted rows are kept so the delete can sync.
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// User who made the last server-accepted change.
  TextColumn get updatedBy => text().nullable()();

  /// Server-assigned global order of the last accepted change.
  IntColumn get serverSeq => integer().nullable()();
}
