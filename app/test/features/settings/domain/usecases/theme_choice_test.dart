import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/settings/domain/usecases/get_theme_choice.dart';
import 'package:mizan/features/settings/domain/usecases/set_theme_choice.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_error.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_failure.dart';
import 'package:mizan/features/settings/domain/value_objects/theme_choice.dart';
import 'package:test/test.dart';

import '../../../../support/fake_device_preferences_repository.dart';

void main() {
  test('follows the phone until a choice is saved', () async {
    final preferences = FakeDevicePreferencesRepository();

    expect(
      await GetThemeChoice(preferences)(),
      const Ok<ThemeChoice, SettingsFailure>(ThemeChoice.system),
    );

    await SetThemeChoice(preferences)(ThemeChoice.dark);
    expect(
      await GetThemeChoice(preferences)(),
      const Ok<ThemeChoice, SettingsFailure>(ThemeChoice.dark),
    );
  });

  test('a failed save is returned, and the choice is unchanged', () async {
    final preferences = FakeDevicePreferencesRepository()
      ..saveFailure = const SettingsFailure(SettingsError.storage);

    expect(
      await SetThemeChoice(preferences)(ThemeChoice.light),
      const Err<void, SettingsFailure>(SettingsFailure(SettingsError.storage)),
    );
    expect(preferences.theme, ThemeChoice.system);
  });
}
