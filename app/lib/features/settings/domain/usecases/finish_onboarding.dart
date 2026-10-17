import '../../../../core/result/result.dart';
import '../repositories/device_preferences_repository.dart';
import '../value_objects/settings_failure.dart';

/// Records that onboarding is done (finished or skipped), so it never shows
/// again on this install.
class FinishOnboarding {
  const FinishOnboarding(this._preferences);

  final DevicePreferencesRepository _preferences;

  Future<Result<void, SettingsFailure>> call() => _preferences.saveOnboarded();
}
