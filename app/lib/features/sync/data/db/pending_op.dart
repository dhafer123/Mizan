import 'outbox_op_type.dart';

/// An op to queue with a local write. `OutboxDao.recordWrite` adds the op id
/// and timestamp.
class PendingOp {
  const PendingOp({
    required this.entity,
    required this.entityId,
    required this.type,
    required this.changedFields,
    required this.baseVersion,
  });

  /// Synced table name, e.g. `expenses`.
  final String entity;
  final String entityId;
  final OutboxOpType type;

  /// JSON-encodable field values; see `syncPayload`.
  final Map<String, Object?> changedFields;
  final int baseVersion;
}
