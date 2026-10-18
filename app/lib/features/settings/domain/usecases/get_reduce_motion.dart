import '../../../../core/result/result.dart';
import '../repositories/device_preferences_repository.dart';
import '../value_objects/settings_failure.dart';

/// Whether the user turned on "Reduce motion" in the app; false (follow the
/// phone) until they do.
class GetReduceMotion {
  const GetReduceMotion(this._preferences);

  final DevicePreferencesRepository _preferences;

  Future<Result<bool, SettingsFailure>> call() =>
      _preferences.loadReduceMotion();
}
