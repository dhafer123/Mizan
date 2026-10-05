import '../../../../core/result/result.dart';
import '../entities/lock_settings.dart';
import '../value_objects/settings_failure.dart';

/// Where the app lock is kept: secure, device-only storage.
abstract interface class LockSettingsRepository {
  /// Null when the lock is off.
  Future<Result<LockSettings?, SettingsFailure>> load();

  /// Null turns the lock off.
  Future<Result<void, SettingsFailure>> save(LockSettings? settings);
}
