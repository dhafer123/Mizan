import 'package:drift/drift.dart';

/// Pull progress. A single row with id 1.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  IntColumn get id => integer()();

  /// The highest `serverSeq` pulled so far.
  IntColumn get cursor => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  /// The account the synced data on this phone belongs to (null until the
  /// first sign-in). Signing in to a different one wipes it (ADR 0007).
  TextColumn get accountId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}
