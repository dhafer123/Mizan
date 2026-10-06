import 'dart:async';

import '../../../../core/result/result.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/value_objects/auth_error.dart';
import '../../domain/value_objects/auth_failure.dart';
import '../../domain/value_objects/credentials.dart';
import '../remote/auth_api.dart';
import '../remote/device_info.dart';
import '../session/session_store.dart';
import '../session/stored_session.dart';

/// [AuthRepository] over the `/auth` API and a [SessionStore]. The session
/// (account + tokens) is only written after the server accepts the sign-in.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, this._store, {required this.platform});

  final AuthApi _api;
  final SessionStore _store;

  /// `android` or `ios`, sent with the device id.
  final String platform;

  final _changes = StreamController<Account?>.broadcast();

  static const _storageFailure = AuthFailure(AuthError.storage);

  @override
  Stream<Account?> watchAccount() {
    late final StreamController<Account?> out;
    StreamSubscription<Account?>? changes;
    out = StreamController<Account?>(
      onListen: () {
        var changed = false;
        // Listen first, so a change during the read isn't lost; the read
        // result is then stale and skipped.
        changes = _changes.stream.listen((account) {
          changed = true;
          out.add(account);
        });
        _store.read().then(
          (session) {
            if (!changed) out.add(session?.account);
          },
          onError: (Object _) {
            if (!changed) out.addError(_storageFailure);
          },
        );
      },
      onCancel: () async {
        await changes?.cancel();
        await out.close();
      },
    );
    return out.stream;
  }

  @override
  Future<Result<Account, AuthFailure>> signUp(Credentials credentials) =>
      _start((device) => _api.signUp(credentials, device));

  @override
  Future<Result<Account, AuthFailure>> logIn(Credentials credentials) =>
      _start((device) => _api.logIn(credentials, device));

  Future<Result<Account, AuthFailure>> _start(
    Future<Result<StoredSession, AuthFailure>> Function(DeviceInfo) call,
  ) async {
    final String deviceId;
    try {
      deviceId = await _store.deviceId();
    } on Object {
      return const Err(_storageFailure);
    }

    final result = await call(DeviceInfo(id: deviceId, platform: platform));
    switch (result) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final session):
        try {
          await _store.write(session);
        } on Object {
          return const Err(_storageFailure);
        }
        _changes.add(session.account);
        return Ok(session.account);
    }
  }

  @override
  Future<Result<void, AuthFailure>> logOut() async {
    final StoredSession? session;
    final String deviceId;
    try {
      session = await _store.read();
      if (session == null) return const Ok(null);
      deviceId = await _store.deviceId();
    } on Object {
      return const Err(_storageFailure);
    }

    try {
      await _api.logOut(
        refreshToken: session.tokens.refresh,
        deviceId: deviceId,
      );
    } on Object {
      // Offline or server error: sign out here anyway. The refresh token
      // then stays valid on the server until it expires (30 days).
    }

    try {
      await _store.clear();
    } on Object {
      return const Err(_storageFailure);
    }
    _changes.add(null);
    return const Ok(null);
  }

  /// The server rejected the refresh token: sign out here. Called by the
  /// `AuthInterceptor`.
  Future<void> endExpiredSession() async {
    try {
      await _store.clear();
    } on Object {
      // Still report signed out; the stale tokens are rejected anyway.
    }
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
