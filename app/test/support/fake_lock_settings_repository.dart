import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/settings/domain/entities/lock_settings.dart';
import 'package:mizan/features/settings/domain/repositories/lock_settings_repository.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_failure.dart';

/// An in-memory [LockSettingsRepository]. Starts with the lock off unless
/// given [settings].
class FakeLockSettingsRepository implements LockSettingsRepository {
  FakeLockSettingsRepository([this.settings]);

  LockSettings? settings;

  /// When set, [load] fails with this.
  SettingsFailure? loadFailure;

  /// When set, [save] fails with this.
  SettingsFailure? saveFailure;

  @override
  Future<Result<LockSettings?, SettingsFailure>> load() async =>
      switch (loadFailure) {
        final failure? => Err(failure),
        null => Ok(settings),
      };

  @override
  Future<Result<void, SettingsFailure>> save(LockSettings? settings) async {
    if (saveFailure case final failure?) return Err(failure);
    this.settings = settings;
    return const Ok(null);
  }
}
