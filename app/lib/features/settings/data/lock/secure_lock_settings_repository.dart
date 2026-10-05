import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/lock_settings.dart';
import '../../domain/repositories/lock_settings_repository.dart';
import '../../domain/value_objects/settings_error.dart';
import '../../domain/value_objects/settings_failure.dart';

/// [LockSettingsRepository] in the platform's secure storage (on Android,
/// encrypted with a Keystore key). Not in drift: the lock is per device and
/// never synced. Storage errors become [SettingsFailure]s.
class SecureLockSettingsRepository implements LockSettingsRepository {
  const SecureLockSettingsRepository(this._storage);

  final FlutterSecureStorage _storage;

  static const pinKey = 'lock.pin';
  static const biometricsKey = 'lock.biometrics';

  static const _failure = SettingsFailure(SettingsError.storage);

  @override
  Future<Result<LockSettings?, SettingsFailure>> load() async {
    try {
      final pin = await _storage.read(key: pinKey);
      if (pin == null) return const Ok(null);
      final biometrics = await _storage.read(key: biometricsKey) == 'true';
      return Ok(LockSettings(pin: pin, biometrics: biometrics));
    } on Object {
      return const Err(_failure);
    }
  }

  @override
  Future<Result<void, SettingsFailure>> save(LockSettings? settings) async {
    try {
      if (settings == null) {
        // The PIN goes first: without it the lock is off either way.
        await _storage.delete(key: pinKey);
        await _storage.delete(key: biometricsKey);
      } else {
        await _storage.write(
          key: biometricsKey,
          value: '${settings.biometrics}',
        );
        await _storage.write(key: pinKey, value: settings.pin);
      }
      return const Ok(null);
    } on Object {
      return const Err(_failure);
    }
  }
}
