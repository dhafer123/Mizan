import 'package:freezed_annotation/freezed_annotation.dart';

part 'lock_settings.freezed.dart';

/// The app lock on this device. Device-only: never synced.
@freezed
abstract class LockSettings with _$LockSettings {
  const factory LockSettings({
    /// The unlock PIN, 4 to 6 digits.
    required String pin,

    /// Whether a fingerprint or face can unlock too (the PIN always can).
    @Default(false) bool biometrics,
  }) = _LockSettings;
}
