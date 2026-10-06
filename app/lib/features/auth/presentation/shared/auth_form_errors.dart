import '../../domain/value_objects/auth_error.dart';
import '../../domain/value_objects/auth_failure.dart';

/// Which form field an [AuthFailure] belongs under. The rest (wrong
/// password, offline, server) show above the submit button.
enum AuthField { displayName, email, password, form }

/// A failure's message, placed under its field.
class AuthFormErrors {
  const AuthFormErrors([this.failure]);

  final AuthFailure? failure;

  static AuthField fieldOf(AuthError error) => switch (error) {
    AuthError.displayNameTooLong => AuthField.displayName,
    AuthError.invalidEmail || AuthError.emailTaken => AuthField.email,
    AuthError.passwordRequired ||
    AuthError.passwordLength ||
    AuthError.weakPassword => AuthField.password,
    AuthError.invalidCredentials ||
    AuthError.tooManyAttempts ||
    AuthError.offline ||
    AuthError.server ||
    AuthError.storage => AuthField.form,
  };

  String? operator [](AuthField field) => switch (failure) {
    final f? when fieldOf(f.error) == field => f.message,
    _ => null,
  };

  /// Typing in [field] clears its error.
  AuthFormErrors clear(AuthField field) =>
      this[field] == null ? this : const AuthFormErrors();
}
