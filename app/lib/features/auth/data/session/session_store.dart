import 'stored_session.dart';

/// Where the session and this install's device id are kept. Methods throw
/// on storage errors; callers in the data layer turn them into failures.
abstract interface class SessionStore {
  /// Null when signed out.
  Future<StoredSession?> read();

  Future<void> write(StoredSession session);

  /// Signs out on this phone. Keeps the device id.
  Future<void> clear();

  /// A UUID made once per install, so the server can tell this phone apart
  /// across sign-outs (push tokens, task 4.6).
  Future<String> deviceId();
}
