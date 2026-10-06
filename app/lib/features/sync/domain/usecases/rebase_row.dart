/// A local change still waiting to be pushed, as stored in the outbox.
typedef QueuedChange = ({String opType, Map<String, Object?> changedFields});

/// The row to store after a pull: the server's [serverRow] with the local
/// [queued] changes for the same row re-applied on top, oldest first. That
/// keeps unsynced edits visible; the server merges them when they're pushed.
///
/// Rows and changes use the app's sync JSON (`syncPayload`): the same keys,
/// so a change is a plain overlay. The server's sync metadata (version,
/// serverSeq, …) is kept, so later ops are based on what was pulled.
Map<String, Object?> rebaseRow(
  Map<String, Object?> serverRow,
  Iterable<QueuedChange> queued,
) {
  final row = {...serverRow};
  for (final change in queued) {
    switch (change.opType) {
      case 'delete':
        row['deleted'] = true;
      case 'create':
        // A queued create is a restore (or a re-create): it undeletes.
        row
          ..addAll(change.changedFields)
          ..['deleted'] = false;
      default:
        row.addAll(change.changedFields);
    }
  }
  return row;
}
