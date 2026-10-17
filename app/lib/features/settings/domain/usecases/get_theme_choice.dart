import '../../../../core/result/result.dart';
import '../repositories/device_preferences_repository.dart';
import '../value_objects/settings_failure.dart';
import '../value_objects/theme_choice.dart';

/// The saved light / dark choice; [ThemeChoice.system] until one is saved.
class GetThemeChoice {
  const GetThemeChoice(this._preferences);

  final DevicePreferencesRepository _preferences;

  Future<Result<ThemeChoice, SettingsFailure>> call() =>
      _preferences.loadThemeChoice();
}
