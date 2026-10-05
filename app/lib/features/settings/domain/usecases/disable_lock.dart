import '../../../../core/result/result.dart';
import '../repositories/lock_settings_repository.dart';
import '../value_objects/settings_failure.dart';

/// Turns the lock off and forgets the PIN.
class DisableLock {
  const DisableLock(this._repository);

  final LockSettingsRepository _repository;

  Future<Result<void, SettingsFailure>> call() => _repository.save(null);
}
