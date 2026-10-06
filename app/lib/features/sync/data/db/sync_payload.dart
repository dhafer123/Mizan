import 'package:drift/drift.dart';

/// Sync metadata keys: set by the server, never sent in an op.
const syncMetadataFields = {'version', 'deleted', 'updatedBy', 'serverSeq'};

/// The JSON form of synced rows, shared with the server: dates as ISO-8601
/// strings. Use it to read pulled rows back too (`Row.fromJson`).
const syncSerializer = ValueSerializer.defaults(
  serializeDateTimeValuesAsString: true,
);

/// A row's syncable fields as JSON-encodable values (dates as ISO-8601),
/// keyed by Dart field name.
Map<String, Object?> syncPayload(DataClass row) =>
    row.toJson(serializer: syncSerializer)
      ..removeWhere((key, _) => syncMetadataFields.contains(key));

/// The fields whose values differ between two versions of a row.
Map<String, Object?> changedSyncFields(DataClass before, DataClass after) {
  final old = syncPayload(before);
  final updated = syncPayload(after);
  return {
    for (final MapEntry(:key, :value) in updated.entries)
      if (old[key] != value) key: value,
  };
}
