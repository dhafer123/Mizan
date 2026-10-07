import 'dart:async';

import '../repositories/push_messaging.dart';
import '../repositories/push_token_repository.dart';
import '../value_objects/push_message.dart';

/// Turns pushes into syncs (ARCHITECTURE.md §6, "When sync runs") and keeps
/// the server's copy of this phone's push token current.
///
/// While an account is signed in: every push calls [onDataChanged] (the
/// sync scheduler's "sync now"), and one with a notification is shown. The
/// token is sent to the server when an account signs in and whenever FCM
/// replaces it; a failed send is retried by [retry] (on app resume).
class PushListener {
  PushListener({
    required PushMessaging push,
    required PushTokenRepository tokens,
    required Stream<String?> accounts,
    required void Function() onDataChanged,
  }) : _push = push,
       _tokens = tokens,
       _accounts = accounts,
       _onDataChanged = onDataChanged;

  final PushMessaging _push;
  final PushTokenRepository _tokens;
  final Stream<String?> _accounts;
  final void Function() _onDataChanged;

  final _subscriptions = <StreamSubscription<Object?>>[];
  final _opened = StreamController<String>.broadcast();
  var _enabled = false;
  var _disposed = false;
  String? _account;
  String? _token;

  /// (account, token) the server has; null until a send succeeds.
  (String, String)? _registered;

  /// Groups whose notification the user tapped, to open them.
  Stream<String> get openedGroups => _opened.stream;

  /// Sets push up and starts listening. Without push (no Firebase config)
  /// it does nothing: sync still runs on its other triggers.
  Future<void> start() async {
    if (!await _push.start() || _disposed) return;
    _enabled = true;
    void ignore(Object _) {}
    _subscriptions
      ..add(_accounts.listen(_onAccount, onError: ignore))
      ..add(_push.watchToken().listen(_onToken, onError: ignore))
      ..add(_push.messages().listen(_onMessage, onError: ignore))
      ..add(_push.opened().listen(_onOpened, onError: ignore));
  }

  /// Sends the token again if the last send failed.
  Future<void> retry() => _register();

  Future<void> dispose() async {
    _disposed = true;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _opened.close();
  }

  void _onAccount(String? account) {
    _account = account;
    unawaited(_register());
  }

  void _onToken(String token) {
    _token = token;
    unawaited(_register());
  }

  void _onMessage(PushMessage message) {
    if (_account == null) return;
    _onDataChanged();
    if (message.title != null) unawaited(_push.show(message));
  }

  void _onOpened(PushMessage message) {
    final group = message.groupId;
    if (_account != null && group != null && !_disposed) _opened.add(group);
  }

  Future<void> _register() async {
    final (account, token) = (_account, _token);
    if (!_enabled || account == null || token == null) return;
    if (_registered == (account, token)) return;
    final result = await _tokens.register(token);
    if (result.isOk) _registered = (account, token);
  }
}
