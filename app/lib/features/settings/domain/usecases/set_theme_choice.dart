import '../../../../core/result/result.dart';
import '../repositories/device_preferences_repository.dart';
import '../value_objects/settings_failure.dart';
import '../value_objects/theme_choice.dart';

/// Saves the light / dark choice on this phone.
class SetThemeChoice {
  const SetThemeChoice(this._preferences);

  final DevicePreferencesRepository _preferences;

  Future<Result<void, SettingsFailure>> call(ThemeChoice choice) =>
      _preferences.saveThemeChoice(choice);
}
