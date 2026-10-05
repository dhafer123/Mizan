import 'package:local_auth/local_auth.dart';

import '../../domain/repositories/biometric_authenticator.dart';

/// [BiometricAuthenticator] with `local_auth`. Biometrics only: the app's
/// own PIN is the fallback, not the phone's.
class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  const LocalAuthBiometricAuthenticator(this._auth);

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on LocalAuthException {
      // Cancelled, locked out, nothing enrolled...: the PIN still works.
      return false;
    } on Object {
      return false;
    }
  }
}
