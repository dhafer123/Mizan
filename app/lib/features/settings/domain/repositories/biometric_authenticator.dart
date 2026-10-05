/// The phone's fingerprint or face check.
abstract interface class BiometricAuthenticator {
  /// Whether the phone can do a biometric check now (hardware present and
  /// something enrolled).
  Future<bool> isAvailable();

  /// Asks the user, showing [reason]. True only if they passed; false if
  /// they failed, cancelled, or it couldn't run.
  Future<bool> authenticate(String reason);
}
