import 'dart:convert';

import '../../../../app/db/app_database.dart';
import '../../domain/entities/history_entry.dart';
import '../../domain/value_objects/change_kind.dart';

abstract final class HistoryMapper {
  /// Throws [FormatException] for a kind this app version doesn't know.
  static HistoryEntry toDomain(EntityHistoryRow row) => HistoryEntry(
    id: row.id,
    entity: row.entity,
    entityId: row.entityId,
    kind:
        ChangeKind.values.asNameMap()[row.kind] ??
        (throw FormatException('Unknown history kind', row.kind)),
    field: row.field,
    oldValue: row.oldValue == null ? null : jsonDecode(row.oldValue!),
    newValue: row.newValue == null ? null : jsonDecode(row.newValue!),
    changedBy: row.changedBy,
    changedAt: row.changedAt.toUtc(),
  );
}
