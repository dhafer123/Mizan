import '../../../../core/result/result.dart';
import '../value_objects/settings_failure.dart';
import '../value_objects/theme_choice.dart';

/// Per-phone preferences that never sync: the theme, reduced motion, and
/// whether this install has been through onboarding.
abstract interface class DevicePreferencesRepository {
  /// [ThemeChoice.system] when none was saved.
  Future<Result<ThemeChoice, SettingsFailure>> loadThemeChoice();

  Future<Result<void, SettingsFailure>> saveThemeChoice(ThemeChoice choice);

  /// False (follow the phone) when none was saved.
  Future<Result<bool, SettingsFailure>> loadReduceMotion();

  Future<Result<void, SettingsFailure>> saveReduceMotion({required bool on});

  /// False until [saveOnboarded] is called.
  Future<Result<bool, SettingsFailure>> loadOnboarded();

  Future<Result<void, SettingsFailure>> saveOnboarded();
}
