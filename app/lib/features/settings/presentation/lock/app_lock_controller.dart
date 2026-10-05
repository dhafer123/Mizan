import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/core_providers.dart';
import '../../../../app/di/settings_providers.dart';

part 'app_lock_controller.g.dart';

enum AppLockState {
  /// Reading whether the lock is on; nothing is shown yet.
  checking,
  locked,
  unlocked,
}

/// Whether the app is locked. Locked at start when the lock is on, and
/// again on coming back after a minute or more in the background.
@Riverpod(keepAlive: true)
class AppLock extends _$AppLock {
  var _enabled = false;
  DateTime? _backgroundedAt;

  @override
  AppLockState build() {
    _load();
    return AppLockState.checking;
  }

  Future<void> _load() async {
    final status = await ref.read(getLockStatusProvider)();
    if (!ref.mounted) return;
    // If secure storage can't be read the PIN can't be checked either, so
    // locking would shut the user out of their own data: stay open.
    _enabled = status.valueOrNull?.enabled ?? false;
    state = _enabled ? AppLockState.locked : AppLockState.unlocked;
  }

  /// The app left the screen. Only the first call counts until [resumed].
  void backgrounded() => _backgroundedAt ??= ref.read(clockProvider).now();

  /// The app is back on screen.
  void resumed() {
    final lock = ref.read(shouldLockOnResumeProvider)(
      lockEnabled: _enabled,
      backgroundedAt: _backgroundedAt,
      now: ref.read(clockProvider).now(),
    );
    _backgroundedAt = null;
    if (lock && state == AppLockState.unlocked) state = AppLockState.locked;
  }

  /// The PIN or biometrics checked out.
  void unlock() => state = AppLockState.unlocked;

  /// The lock was turned on or off in settings.
  void setEnabled({required bool enabled}) => _enabled = enabled;
}
