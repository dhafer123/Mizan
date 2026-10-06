import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/ids/id_generator.dart';
import '../mappers/session_mapper.dart';
import 'session_store.dart';
import 'stored_session.dart';

/// [SessionStore] in the platform's secure storage (on Android, encrypted
/// with a Keystore key). The session is one JSON value, so the account and
/// its tokens are always written together. Reads are cached: the API
/// client asks for the token on every request.
class SecureSessionStore implements SessionStore {
  SecureSessionStore(this._storage, this._ids);

  final FlutterSecureStorage _storage;
  final IdGenerator _ids;

  static const sessionKey = 'auth.session';
  static const deviceIdKey = 'device.id';

  // Null until the first read; then the stored value (which may be null).
  ({StoredSession? session})? _cache;
  String? _deviceId;

  @override
  Future<StoredSession?> read() async {
    if (_cache case (:final session)) return session;
    final raw = await _storage.read(key: sessionKey);
    StoredSession? session;
    if (raw != null) {
      try {
        session = SessionMapper.sessionFromJson(jsonDecode(raw));
      } on FormatException {
        // Unreadable (e.g. an older format): treat as signed out.
        await _storage.delete(key: sessionKey);
      }
    }
    _cache = (session: session);
    return session;
  }

  @override
  Future<void> write(StoredSession session) async {
    _cache = null; // If the write fails, the next read goes to storage.
    await _storage.write(
      key: sessionKey,
      value: jsonEncode(SessionMapper.sessionToJson(session)),
    );
    _cache = (session: session);
  }

  @override
  Future<void> clear() async {
    _cache = null;
    await _storage.delete(key: sessionKey);
    _cache = (session: null);
  }

  @override
  Future<String> deviceId() async {
    if (_deviceId case final id?) return id;
    var id = await _storage.read(key: deviceIdKey);
    if (id == null) {
      id = _ids.newId();
      await _storage.write(key: deviceIdKey, value: id);
    }
    _deviceId = id;
    return id;
  }
}
