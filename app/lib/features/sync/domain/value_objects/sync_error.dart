/// Why a sync didn't finish.
enum SyncError {
  /// The server couldn't be reached (no network, timeout).
  offline,

  /// The server failed or answered with something unexpected.
  server,

  /// The server ended the session (refresh token rejected): signed out.
  sessionExpired,

  /// The local database failed.
  storage,

  /// A different account signed in while syncing; this run was dropped.
  accountChanged,
}
