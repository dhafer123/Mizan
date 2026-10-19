import '../../../../core/result/result.dart';
import '../repositories/device_preferences_repository.dart';
import '../value_objects/settings_failure.dart';

/// Voice input was used: Home stops pointing it out on this phone.
class DismissVoiceHint {
  const DismissVoiceHint(this._preferences);

  final DevicePreferencesRepository _preferences;

  Future<Result<void, SettingsFailure>> call() =>
      _preferences.saveVoiceHintSeen();
}
