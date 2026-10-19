import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/settings/domain/usecases/dismiss_voice_hint.dart';
import 'package:mizan/features/settings/domain/usecases/should_show_voice_hint.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_error.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_failure.dart';
import 'package:test/test.dart';

import '../../../../support/fake_device_preferences_repository.dart';

void main() {
  test('shown until dismissed, then never again', () async {
    final preferences = FakeDevicePreferencesRepository();

    expect(
      await ShouldShowVoiceHint(preferences)(),
      const Ok<bool, SettingsFailure>(true),
    );

    await DismissVoiceHint(preferences)();
    expect(
      await ShouldShowVoiceHint(preferences)(),
      const Ok<bool, SettingsFailure>(false),
    );
  });

  test('a failed read is returned', () async {
    final preferences = FakeDevicePreferencesRepository()
      ..loadFailure = const SettingsFailure(SettingsError.storage);

    expect(
      await ShouldShowVoiceHint(preferences)(),
      const Err<bool, SettingsFailure>(SettingsFailure(SettingsError.storage)),
    );
  });
}
