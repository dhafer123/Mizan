import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/change_kind.dart';

part 'history_entry.freezed.dart';

/// One change to a group's data, as the server recorded it ("Ali changed
/// amount 120 → 150"). Values are the sync JSON values (money in minor
/// units, members by id).
@freezed
abstract class HistoryEntry with _$HistoryEntry {
  const factory HistoryEntry({
    required String id,

    /// `groups`, `members` or `shared_expenses`.
    required String entity,
    required String entityId,
    required ChangeKind kind,

    /// The field's sync name (e.g. `amountMinor`); empty for whole-row
    /// events (created, deleted, restored).
    required String field,
    Object? oldValue,
    Object? newValue,

    /// The account that made the change.
    String? changedBy,
    required DateTime changedAt,
  }) = _HistoryEntry;
}
