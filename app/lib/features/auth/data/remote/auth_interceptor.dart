import 'package:dio/dio.dart';

import '../session/session_store.dart';
import '../session/stored_session.dart';
import 'auth_api.dart';

/// Adds the access token to every request, and on a 401 refreshes the
/// tokens once and retries the request.
///
/// - Errors are queued ([QueuedInterceptor]), so when several requests fail
///   together only the first refreshes; the rest see the new token and just
///   retry. That matters because a refresh token works only once.
/// - If the server rejects the refresh token (revoked, expired, password
///   changed), the session is over: [onSessionExpired] signs out locally and
///   the original 401 is passed on. Unless storage now holds a different
///   refresh token: another isolate (background sync) refreshed first, so
///   the request is retried with that pair.
/// - If the refresh can't reach the server, the session is kept and the
///   original error is passed on; the next request tries again.
/// - A retried request that fails again is passed on as is (no loop).
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required SessionStore store,
    required AuthApi api,
    required Dio retryDio,
    required Future<void> Function() onSessionExpired,
  }) : _store = store,
       _api = api,
       _retryDio = retryDio,
       _onSessionExpired = onSessionExpired;

  final SessionStore _store;
  final AuthApi _api;

  /// Sends the retried request. Must not have this interceptor.
  final Dio _retryDio;
  final Future<void> Function() _onSessionExpired;

  static const _retriedKey = 'auth.retried';
  static const _header = 'Authorization';

  static String _bearer(String access) => 'Bearer $access';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final session = await _readSession();
    if (session != null) {
      options.headers[_header] = _bearer(session.tokens.access);
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final sent = options.headers[_header];
    if (err.response?.statusCode != 401 ||
        sent == null ||
        options.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    final current = await _readSession();
    if (current == null) return handler.next(err); // Signed out meanwhile.
    var session = current;

    // Still the token that failed: this request is the first to notice.
    if (sent == _bearer(current.tokens.access)) {
      try {
        final tokens = await _api.refresh(current.tokens.refresh);
        session = current.copyWith(tokens: tokens);
        await _store.write(session);
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status != 400 && status != 401) return handler.next(err);
        // Refresh tokens work once. If another isolate (background sync)
        // refreshed first, ours was just used up: take the stored new pair.
        final stored = await _readSession(fresh: true);
        if (stored == null || stored.tokens.refresh == current.tokens.refresh) {
          await _onSessionExpired();
          return handler.next(err);
        }
        session = stored;
      } on Object {
        // A bad response body or a storage error: keep the session.
        return handler.next(err);
      }
    }

    final retry = options.copyWith(
      headers: {...options.headers, _header: _bearer(session.tokens.access)},
      extra: {...options.extra, _retriedKey: true},
    );
    try {
      handler.resolve(await _retryDio.fetch<Object?>(retry));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<StoredSession?> _readSession({bool fresh = false}) async {
    try {
      return await _store.read(fresh: fresh);
    } on Object {
      return null; // Unreadable storage: send without a token.
    }
  }
}
