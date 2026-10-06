import 'package:freezed_annotation/freezed_annotation.dart';

part 'credentials.freezed.dart';

/// What the user typed to sign up or sign in, checked and cleaned up by
/// `ValidateCredentials`.
@freezed
abstract class Credentials with _$Credentials {
  const factory Credentials({
    /// Trimmed and lowercased.
    required String email,

    /// Exactly as typed: spaces count.
    required String password,

    /// Sign-up only. Trimmed; null when blank.
    String? displayName,
  }) = _Credentials;

  const Credentials._();

  /// Never prints the password (logs, test failures).
  @override
  String toString() =>
      'Credentials(email: $email, password: ***, displayName: $displayName)';
}
