import '../../../../core/result/failure.dart';
import 'settings_error.dart';

class SettingsFailure extends Failure {
  const SettingsFailure(this.error);

  final SettingsError error;

  @override
  String get message => switch (error) {
    SettingsError.pinFormat => 'The PIN must be 4 to 6 digits.',
    SettingsError.pinMismatch => "The PINs don't match. Try again.",
    SettingsError.wrongPin => 'Wrong PIN.',
    SettingsError.tooManyAttempts =>
      'Too many wrong PINs. Wait 30 seconds and try again.',
    SettingsError.biometricsUnavailable =>
      'Set up a fingerprint or face unlock on this phone first.',
    SettingsError.biometricsFailed => "Couldn't confirm it's you.",
    SettingsError.nothingToExport => 'No expenses to export yet.',
    SettingsError.exportFailed => "Couldn't write the file. Try again.",
    SettingsError.storage => "Couldn't save on this device. Try again.",
  };

  @override
  bool operator ==(Object other) =>
      other is SettingsFailure && other.error == error;

  @override
  int get hashCode => error.hashCode;
}
