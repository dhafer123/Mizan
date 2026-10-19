import '../../../../core/result/result.dart';
import '../repositories/device_preferences_repository.dart';
import '../value_objects/settings_failure.dart';

/// Whether Home should point out voice input: until it's first used on
/// this phone.
class ShouldShowVoiceHint {
  const ShouldShowVoiceHint(this._preferences);

  final DevicePreferencesRepository _preferences;

  Future<Result<bool, SettingsFailure>> call() async =>
      (await _preferences.loadVoiceHintSeen()).map((seen) => !seen);
}
