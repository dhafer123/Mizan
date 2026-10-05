import '../../../../core/result/result.dart';
import '../value_objects/settings_error.dart';
import '../value_objects/settings_failure.dart';

/// A PIN is 4 to 6 digits (0-9 only).
class ValidatePin {
  const ValidatePin();

  static const minLength = 4;
  static const maxLength = 6;

  Result<String, SettingsFailure> call(String pin) {
    final ok =
        pin.length >= minLength &&
        pin.length <= maxLength &&
        pin.codeUnits.every((c) => c >= 0x30 && c <= 0x39);
    return ok ? Ok(pin) : const Err(SettingsFailure(SettingsError.pinFormat));
  }
}
