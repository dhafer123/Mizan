import '../../../../core/result/result.dart';
import '../repositories/device_preferences_repository.dart';
import '../value_objects/settings_failure.dart';

/// Saves the app's "Reduce motion" switch on this phone.
class SetReduceMotion {
  const SetReduceMotion(this._preferences);

  final DevicePreferencesRepository _preferences;

  Future<Result<void, SettingsFailure>> call({required bool on}) =>
      _preferences.saveReduceMotion(on: on);
}
