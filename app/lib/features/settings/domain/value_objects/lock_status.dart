import 'package:freezed_annotation/freezed_annotation.dart';

part 'lock_status.freezed.dart';

/// What the settings screen shows about the app lock. Never the PIN.
@freezed
abstract class LockStatus with _$LockStatus {
  const factory LockStatus({
    required bool enabled,
    required bool biometrics,

    /// Whether this phone can do a biometric check at all.
    required bool biometricsAvailable,
  }) = _LockStatus;
}
