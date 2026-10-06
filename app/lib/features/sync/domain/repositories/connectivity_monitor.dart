/// Whether the phone has a network connection. It may still be unable to
/// reach the server; sync treats that as offline too.
abstract interface class ConnectivityMonitor {
  /// The current state, then every change.
  Stream<bool> watchOnline();
}
