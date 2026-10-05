import '../../../../core/result/result.dart';
import '../repositories/biometric_authenticator.dart';
import '../repositories/lock_settings_repository.dart';
import '../value_objects/lock_status.dart';
import '../value_objects/settings_failure.dart';

/// Whether the lock is on, and whether biometrics can (and do) unlock it.
class GetLockStatus {
  const GetLockStatus(this._repository, this._biometrics);

  final LockSettingsRepository _repository;
  final BiometricAuthenticator _biometrics;

  Future<Result<LockStatus, SettingsFailure>> call() async {
    final loaded = await _repository.load();
    if (loaded case Err(:final failure)) return Err(failure);
    final settings = loaded.valueOrNull;
    return Ok(
      LockStatus(
        enabled: settings != null,
        biometrics: settings?.biometrics ?? false,
        biometricsAvailable: await _biometrics.isAvailable(),
      ),
    );
  }
}
