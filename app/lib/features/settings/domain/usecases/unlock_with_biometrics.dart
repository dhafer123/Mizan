import '../../../../core/result/result.dart';
import '../repositories/biometric_authenticator.dart';
import '../repositories/lock_settings_repository.dart';
import '../value_objects/settings_error.dart';
import '../value_objects/settings_failure.dart';

/// Unlocks with a fingerprint or face, if the user turned that on.
class UnlockWithBiometrics {
  const UnlockWithBiometrics(this._repository, this._biometrics);

  final LockSettingsRepository _repository;
  final BiometricAuthenticator _biometrics;

  static const reason = 'Unlock Mizan';

  Future<Result<void, SettingsFailure>> call() async {
    final loaded = await _repository.load();
    if (loaded case Err(:final failure)) return Err(failure);
    if (loaded.valueOrNull?.biometrics != true) {
      return const Err(SettingsFailure(SettingsError.biometricsUnavailable));
    }
    return await _biometrics.authenticate(reason)
        ? const Ok(null)
        : const Err(SettingsFailure(SettingsError.biometricsFailed));
  }
}
