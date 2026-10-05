import 'package:drift/drift.dart';

import 'outbox_op_type.dart';
import 'outbox_status.dart';

/// Local changes waiting to be pushed, in the order they were made
/// (ARCHITECTURE.md §5). Every synced write appends here in the same
/// transaction.
@DataClassName('OutboxEntry')
@TableIndex(name: 'outbox_status_seq', columns: {#status, #seq})
class Outbox extends Table {
  /// Local FIFO order. Only orders this device's ops; never sent.
  IntColumn get seq => integer().autoIncrement()();

  /// Idempotency key: the server ignores an op id it has already applied.
  TextColumn get opId => text().unique()();

  /// Synced table name, e.g. `expenses`.
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get opType => textEnum<OutboxOpType>()();

  /// JSON object of the fields this op sets (all fields for a create).
  TextColumn get changedFields => text()();

  /// The row's `version` when the change was made, for conflict detection.
  IntColumn get baseVersion => integer()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get status => textEnum<OutboxStatus>().withDefault(
    Constant(OutboxStatus.pending.name),
  )();
}
