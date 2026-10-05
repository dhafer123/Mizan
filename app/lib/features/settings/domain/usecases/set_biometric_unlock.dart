import '../../../../core/result/result.dart';
import '../repositories/biometric_authenticator.dart';
import '../repositories/lock_settings_repository.dart';
import '../value_objects/settings_error.dart';
import '../value_objects/settings_failure.dart';

/// Lets a fingerprint or face unlock the app, or stops it. Turning it on
/// needs the lock on, biometrics on the phone, and one successful check.
class SetBiometricUnlock {
  const SetBiometricUnlock(this._repository, this._biometrics);

  final LockSettingsRepository _repository;
  final BiometricAuthenticator _biometrics;

  static const reason = 'Confirm to unlock Mizan with biometrics';

  Future<Result<void, SettingsFailure>> call({required bool enabled}) async {
    final loaded = await _repository.load();
    if (loaded case Err(:final failure)) return Err(failure);
    final settings = loaded.valueOrNull;
    if (settings == null) {
      return enabled
          ? const Err(SettingsFailure(SettingsError.biometricsUnavailable))
          : const Ok(null);
    }
    if (enabled) {
      if (!await _biometrics.isAvailable()) {
        return const Err(SettingsFailure(SettingsError.biometricsUnavailable));
      }
      if (!await _biometrics.authenticate(reason)) {
        return const Err(SettingsFailure(SettingsError.biometricsFailed));
      }
    }
    return _repository.save(settings.copyWith(biometrics: enabled));
  }
}
