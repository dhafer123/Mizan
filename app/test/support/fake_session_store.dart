import 'package:mizan/features/auth/data/session/session_store.dart';
import 'package:mizan/features/auth/data/session/stored_session.dart';

/// An in-memory [SessionStore]. Set [error] to make every call throw.
class FakeSessionStore implements SessionStore {
  FakeSessionStore([this.session]);

  StoredSession? session;
  String id = 'device-1';
  Object? error;

  /// How many times [write] ran.
  var writes = 0;

  void _maybeThrow() {
    if (error case final e?) throw e;
  }

  @override
  Future<StoredSession?> read() async {
    _maybeThrow();
    return session;
  }

  @override
  Future<void> write(StoredSession session) async {
    _maybeThrow();
    writes++;
    this.session = session;
  }

  @override
  Future<void> clear() async {
    _maybeThrow();
    session = null;
  }

  @override
  Future<String> deviceId() async {
    _maybeThrow();
    return id;
  }
}
