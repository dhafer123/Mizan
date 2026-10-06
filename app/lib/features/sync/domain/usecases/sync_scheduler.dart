import 'dart:async';

import '../../../../core/result/result.dart';
import '../entities/sync_status.dart';
import '../repositories/background_sync.dart';
import '../value_objects/outbox_counts.dart';
import '../value_objects/sync_error.dart';
import '../value_objects/sync_failure.dart';
import '../value_objects/sync_phase.dart';
import 'backoff_policy.dart';
import 'claim_local_data.dart';
import 'sync_now.dart';

/// Starts a timer; `Timer.new` in the app, a fake in tests.
typedef StartTimer = Timer Function(Duration delay, void Function() callback);

/// Decides when to sync (ARCHITECTURE.md §6, "When sync runs") and reports
/// a [SyncStatus] for the indicator.
///
/// Triggers: an account signing in, the network coming back, a local write
/// (debounced, so a burst of edits is one sync), the app resuming, and
/// [syncNow]. A failed sync is retried with [BackoffPolicy]. Only one sync
/// runs at a time; a trigger during a run queues exactly one more run.
class SyncScheduler {
  SyncScheduler({
    required SyncNow syncNow,
    required ClaimLocalData claim,
    required Future<DateTime?> Function() lastSyncAt,
    required Stream<String?> accounts,
    required Stream<bool> online,
    required Stream<OutboxCounts> outbox,
    required BackgroundSync background,
    BackoffPolicy backoff = const BackoffPolicy(),
    this.debounce = const Duration(seconds: 2),
    StartTimer startTimer = Timer.new,
    double Function()? random,
  }) : _syncNow = syncNow,
       _claim = claim,
       _lastSyncAt = lastSyncAt,
       _accounts = accounts,
       _online = online,
       _outbox = outbox,
       _background = background,
       _backoff = backoff,
       _startTimer = startTimer,
       _random = random;

  final SyncNow _syncNow;
  final ClaimLocalData _claim;
  final Future<DateTime?> Function() _lastSyncAt;
  final Stream<String?> _accounts;
  final Stream<bool> _online;
  final Stream<OutboxCounts> _outbox;
  final BackgroundSync _background;
  final BackoffPolicy _backoff;
  final StartTimer _startTimer;
  final double Function()? _random;

  /// Quiet time after a local write before syncing it.
  final Duration debounce;

  final _statusController = StreamController<SyncStatus>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  var _status = const SyncStatus();

  String? _account;

  /// The account whose local data is claimed and ready to sync.
  String? _ready;
  var _isOnline = false;
  var _running = false;
  var _again = false;
  var _attempt = 0;
  var _disposed = false;
  Timer? _debounceTimer;
  Timer? _retryTimer;

  SyncStatus get status => _status;

  /// [status], then every change.
  Stream<SyncStatus> watchStatus() async* {
    yield _status;
    yield* _statusController.stream;
  }

  /// Starts listening to the triggers. Call once.
  void start() {
    unawaited(
      _lastSyncAt().then((at) {
        if (at != null && _status.lastSyncAt == null) {
          _emit(_status.copyWith(lastSyncAt: at));
        }
      }, onError: (Object _) {}),
    );
    // A trigger stream that fails (e.g. storage) just stops triggering;
    // "Sync now" and the other triggers still work.
    void ignore(Object _) {}
    _subscriptions
      ..add(_online.listen(_onOnline, onError: ignore))
      ..add(_outbox.listen(_onOutbox, onError: ignore))
      ..add(_accounts.listen(_onAccount, onError: ignore));
  }

  /// "Sync now" from the UI, and app resume.
  void syncNow() => _trigger();

  Future<void> dispose() async {
    _disposed = true;
    _cancelTimers();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _statusController.close();
  }

  // --- Triggers ---

  Future<void> _onAccount(String? account) async {
    if (account == _account) return;
    _account = account;
    _ready = null;
    _cancelTimers();
    _attempt = 0;
    if (account == null) {
      _emit(_status.copyWith(phase: SyncPhase.signedOut, failure: null));
      await _background.disable();
      return;
    }

    final claimed = await _claim(account);
    if (_account != account) return; // Switched again meanwhile.
    if (claimed case Err(:final failure)) {
      _emit(_status.copyWith(phase: SyncPhase.error, failure: failure));
      return;
    }
    if (claimed.valueOrNull == true) {
      _emit(_status.copyWith(lastSyncAt: null));
    }
    _ready = account;
    await _background.enable();
    _emit(_status.copyWith(phase: _restingPhase, failure: null));
    _trigger();
  }

  void _onOnline(bool online) {
    final cameBack = online && !_isOnline;
    _isOnline = online;
    if (_ready == null) return;
    if (!online) {
      _emit(_status.copyWith(phase: SyncPhase.offline));
    } else if (cameBack) {
      _attempt = 0;
      _trigger();
    }
  }

  void _onOutbox(OutboxCounts counts) {
    final wrote = counts.pending > _status.outbox.pending;
    _emit(_status.copyWith(outbox: counts));
    if (wrote && _ready != null) {
      _debounceTimer?.cancel();
      _debounceTimer = _startTimer(debounce, _trigger);
    }
  }

  // --- Running ---

  SyncPhase get _restingPhase {
    if (_ready == null) return SyncPhase.signedOut;
    return _isOnline ? SyncPhase.idle : SyncPhase.offline;
  }

  void _trigger() {
    if (_disposed) return;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    unawaited(_run());
  }

  Future<void> _run() async {
    final account = _ready;
    if (account == null || !_isOnline) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    _emit(_status.copyWith(phase: SyncPhase.syncing, failure: null));

    final result = await _syncNow(accountId: account);
    _running = false;
    if (_disposed || _ready != account) return;

    switch (result) {
      case Ok(value: (_, final at)):
        _attempt = 0;
        _emit(
          _status.copyWith(phase: _restingPhase, lastSyncAt: at, failure: null),
        );
        if (_again) {
          _again = false;
          unawaited(_run());
        }
      case Err(:final failure):
        _again = false;
        _onFailure(failure);
    }
  }

  void _onFailure(SyncFailure failure) {
    switch (failure.error) {
      case SyncError.sessionExpired || SyncError.accountChanged:
        // The account stream follows with the new state; don't retry.
        _emit(_status.copyWith(phase: _restingPhase, failure: failure));
      case SyncError.offline:
        _emit(_status.copyWith(phase: SyncPhase.offline, failure: failure));
        _scheduleRetry();
      case SyncError.server || SyncError.storage:
        _emit(_status.copyWith(phase: SyncPhase.error, failure: failure));
        _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    final delay = _backoff(_attempt++, random: _random);
    _retryTimer?.cancel();
    _retryTimer = _startTimer(delay, _trigger);
  }

  void _cancelTimers() {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
  }

  void _emit(SyncStatus status) {
    if (_disposed || status == _status) return;
    _status = status;
    _statusController.add(status);
  }
}
