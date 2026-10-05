import 'package:drift/drift.dart';

/// Pull progress. A single row with id 1.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  IntColumn get id => integer()();

  /// The highest `serverSeq` pulled so far.
  IntColumn get cursor => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}
