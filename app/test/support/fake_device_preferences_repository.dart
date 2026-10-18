import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/settings/domain/repositories/device_preferences_repository.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_failure.dart';
import 'package:mizan/features/settings/domain/value_objects/theme_choice.dart';

/// An in-memory [DevicePreferencesRepository]. Starts on the system theme
/// and not onboarded unless told otherwise.
class FakeDevicePreferencesRepository implements DevicePreferencesRepository {
  FakeDevicePreferencesRepository({
    this.theme = ThemeChoice.system,
    this.onboarded = false,
    this.reduceMotion = false,
  });

  ThemeChoice theme;
  bool onboarded;
  bool reduceMotion;

  /// When set, every load fails with this.
  SettingsFailure? loadFailure;

  /// When set, every save fails with this.
  SettingsFailure? saveFailure;

  @override
  Future<Result<ThemeChoice, SettingsFailure>> loadThemeChoice() async =>
      switch (loadFailure) {
        final failure? => Err(failure),
        null => Ok(theme),
      };

  @override
  Future<Result<void, SettingsFailure>> saveThemeChoice(
    ThemeChoice choice,
  ) async {
    if (saveFailure case final failure?) return Err(failure);
    theme = choice;
    return const Ok(null);
  }

  @override
  Future<Result<bool, SettingsFailure>> loadReduceMotion() async =>
      switch (loadFailure) {
        final failure? => Err(failure),
        null => Ok(reduceMotion),
      };

  @override
  Future<Result<void, SettingsFailure>> saveReduceMotion({
    required bool on,
  }) async {
    if (saveFailure case final failure?) return Err(failure);
    reduceMotion = on;
    return const Ok(null);
  }

  @override
  Future<Result<bool, SettingsFailure>> loadOnboarded() async =>
      switch (loadFailure) {
        final failure? => Err(failure),
        null => Ok(onboarded),
      };

  @override
  Future<Result<void, SettingsFailure>> saveOnboarded() async {
    if (saveFailure case final failure?) return Err(failure);
    onboarded = true;
    return const Ok(null);
  }
}
