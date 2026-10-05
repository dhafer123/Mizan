/// Why a lock or export action failed.
enum SettingsError {
  /// A PIN that isn't 4 to 6 digits.
  pinFormat,

  /// The confirmation doesn't match the new PIN.
  pinMismatch,

  /// The PIN entered to unlock is wrong.
  wrongPin,

  /// Too many wrong PINs in a row; wait before trying again.
  tooManyAttempts,

  /// The phone has no biometrics set up, or the lock is off.
  biometricsUnavailable,

  /// The biometric check failed or was cancelled.
  biometricsFailed,

  /// There is nothing to export.
  nothingToExport,

  /// The exported file couldn't be written.
  exportFailed,

  /// Secure storage or the local database failed.
  storage,
}
