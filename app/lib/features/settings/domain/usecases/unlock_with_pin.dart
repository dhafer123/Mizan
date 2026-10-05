import '../../../../core/clock/clock.dart';
import '../../../../core/result/result.dart';
import '../repositories/lock_settings_repository.dart';
import '../value_objects/settings_error.dart';
import '../value_objects/settings_failure.dart';

/// Checks a PIN to unlock. After [maxAttempts] wrong PINs in a row, every
/// try is refused for [cooldown].
///
/// The count lives in this object (one per app run), so a restart resets
/// it. It only slows guessing down.
class UnlockWithPin {
  UnlockWithPin(this._repository, this._clock);

  final LockSettingsRepository _repository;
  final Clock _clock;

  static const maxAttempts = 5;
  static const cooldown = Duration(seconds: 30);

  var _wrong = 0;
  DateTime? _blockedUntil;

  Future<Result<void, SettingsFailure>> call(String pin) async {
    final now = _clock.now();
    if (_blockedUntil case final until? when now.isBefore(until)) {
      return const Err(SettingsFailure(SettingsError.tooManyAttempts));
    }
    final loaded = await _repository.load();
    if (loaded case Err(:final failure)) return Err(failure);
    final settings = loaded.valueOrNull;
    // With no lock set, there is nothing to unlock.
    if (settings == null || _matches(settings.pin, pin)) {
      _wrong = 0;
      _blockedUntil = null;
      return const Ok(null);
    }
    _wrong++;
    if (_wrong >= maxAttempts) {
      _wrong = 0;
      _blockedUntil = now.add(cooldown);
      return const Err(SettingsFailure(SettingsError.tooManyAttempts));
    }
    return const Err(SettingsFailure(SettingsError.wrongPin));
  }

  /// Compares every character, so the time taken gives no hint of how much
  /// of the PIN was right.
  static bool _matches(String expected, String given) {
    var diff = expected.length ^ given.length;
    for (var i = 0; i < expected.length; i++) {
      final c = i < given.length ? given.codeUnitAt(i) : 0;
      diff |= expected.codeUnitAt(i) ^ c;
    }
    return diff == 0;
  }
}
