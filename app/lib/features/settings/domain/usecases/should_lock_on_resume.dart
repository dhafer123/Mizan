/// Whether coming back to the app should show the lock: the lock is on and
/// the app was in the background for at least [after].
class ShouldLockOnResume {
  const ShouldLockOnResume();

  static const after = Duration(minutes: 1);

  bool call({
    required bool lockEnabled,

    /// When the app went to the background; null if it didn't.
    required DateTime? backgroundedAt,
    required DateTime now,
  }) {
    if (!lockEnabled || backgroundedAt == null) return false;
    final away = now.difference(backgroundedAt);
    // A clock that went backwards can't show the app was away only briefly.
    return away.isNegative || away >= after;
  }
}
