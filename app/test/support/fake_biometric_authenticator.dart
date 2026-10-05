import 'package:mizan/features/settings/domain/repositories/biometric_authenticator.dart';

/// A [BiometricAuthenticator] that answers as told.
class FakeBiometricAuthenticator implements BiometricAuthenticator {
  FakeBiometricAuthenticator({this.available = true, this.passes = true});

  bool available;
  bool passes;

  /// Every reason [authenticate] was called with, in order.
  final reasons = <String>[];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    reasons.add(reason);
    return available && passes;
  }
}
