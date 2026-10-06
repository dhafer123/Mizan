import '../../../../core/result/result.dart';
import '../value_objects/auth_error.dart';
import '../value_objects/auth_failure.dart';
import '../value_objects/credentials.dart';

/// Checks sign-up or sign-in input before it goes to the server, and returns
/// it cleaned up. The server checks again (and also rejects weak passwords).
class ValidateCredentials {
  const ValidateCredentials();

  static const maxEmailLength = 254;
  static const minPasswordLength = 8;
  static const maxPasswordLength = 128;
  static const maxDisplayNameLength = 50;

  // Deliberately loose: one @, no spaces, a dot in the domain. The server
  // has the final say.
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// [newAccount] applies the sign-up rules: password length and the
  /// display name. Sign-in only needs a password to be there.
  Result<Credentials, AuthFailure> call({
    required String email,
    required String password,
    String? displayName,
    required bool newAccount,
  }) {
    Err<Credentials, AuthFailure> fail(AuthError error) =>
        Err(AuthFailure(error));

    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.length > maxEmailLength || !_email.hasMatch(cleanEmail)) {
      return fail(AuthError.invalidEmail);
    }

    if (password.isEmpty) return fail(AuthError.passwordRequired);
    if (!newAccount) {
      return Ok(Credentials(email: cleanEmail, password: password));
    }

    if (password.length < minPasswordLength ||
        password.length > maxPasswordLength) {
      return fail(AuthError.passwordLength);
    }

    final name = displayName?.trim();
    if (name != null && name.length > maxDisplayNameLength) {
      return fail(AuthError.displayNameTooLong);
    }

    return Ok(
      Credentials(
        email: cleanEmail,
        password: password,
        displayName: name == null || name.isEmpty ? null : name,
      ),
    );
  }
}
