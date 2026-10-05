import 'package:drift/drift.dart';

/// Sync metadata keys: set by the server, never sent in an op.
const syncMetadataFields = {'version', 'deleted', 'updatedBy', 'serverSeq'};

const _serializer = ValueSerializer.defaults(
  serializeDateTimeValuesAsString: true,
);

/// A row's syncable fields as JSON-encodable values (dates as ISO-8601),
/// keyed by Dart field name.
Map<String, Object?> syncPayload(DataClass row) =>
    row.toJson(serializer: _serializer)
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
