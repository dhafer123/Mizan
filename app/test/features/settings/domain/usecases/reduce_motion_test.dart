import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/settings/domain/usecases/get_reduce_motion.dart';
import 'package:mizan/features/settings/domain/usecases/set_reduce_motion.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_error.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_failure.dart';
import 'package:test/test.dart';

import '../../../../support/fake_device_preferences_repository.dart';

void main() {
  test('off (follow the phone) until turned on', () async {
    final preferences = FakeDevicePreferencesRepository();

    expect(
      await GetReduceMotion(preferences)(),
      const Ok<bool, SettingsFailure>(false),
    );

    await SetReduceMotion(preferences)(on: true);
    expect(
      await GetReduceMotion(preferences)(),
      const Ok<bool, SettingsFailure>(true),
    );
  });

  test('a failed save is returned, and the switch is unchanged', () async {
    final preferences = FakeDevicePreferencesRepository()
      ..saveFailure = const SettingsFailure(SettingsError.storage);

    expect(
      await SetReduceMotion(preferences)(on: true),
      const Err<void, SettingsFailure>(SettingsFailure(SettingsError.storage)),
    );
    expect(preferences.reduceMotion, isFalse);
  });
}
