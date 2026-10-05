import '../../../../core/result/result.dart';
import '../entities/lock_settings.dart';
import '../repositories/lock_settings_repository.dart';
import '../value_objects/settings_error.dart';
import '../value_objects/settings_failure.dart';
import 'validate_pin.dart';

/// Turns the lock on with [pin], or changes the PIN (keeping the
/// biometrics choice). The confirmation must match.
class SetPin {
  const SetPin(this._repository, this._validate);

  final LockSettingsRepository _repository;
  final ValidatePin _validate;

  Future<Result<void, SettingsFailure>> call({
    required String pin,
    required String confirmation,
  }) async {
    if (_validate(pin) case Err(:final failure)) return Err(failure);
    if (pin != confirmation) {
      return const Err(SettingsFailure(SettingsError.pinMismatch));
    }
    final loaded = await _repository.load();
    if (loaded case Err(:final failure)) return Err(failure);
    final biometrics = loaded.valueOrNull?.biometrics ?? false;
    return _repository.save(LockSettings(pin: pin, biometrics: biometrics));
  }
}
