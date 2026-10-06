/// What sync is doing right now.
enum SyncPhase {
  /// No account: local-only mode, nothing to sync.
  signedOut,

  /// Up to date, or waiting for the next trigger.
  idle,

  /// Pushing or pulling.
  syncing,

  /// No network; changes wait in the outbox.
  offline,

  /// The last try failed; a retry is scheduled.
  error,
}
