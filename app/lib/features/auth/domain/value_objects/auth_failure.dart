import '../../../../core/result/failure.dart';
import 'auth_error.dart';

class AuthFailure extends Failure {
  const AuthFailure(this.error);

  final AuthError error;

  @override
  String get message => switch (error) {
    AuthError.invalidEmail => 'Enter a valid email address.',
    AuthError.passwordRequired => 'Enter your password.',
    AuthError.passwordLength => 'Use 8 to 128 characters.',
    AuthError.weakPassword =>
      'That password is too easy to guess. Try a longer one, '
          'not only numbers and not like your email.',
    AuthError.displayNameTooLong => 'Use 50 characters or fewer.',
    AuthError.emailTaken =>
      'An account with this email already exists. Sign in instead.',
    AuthError.invalidCredentials => 'Wrong email or password.',
    AuthError.tooManyAttempts => 'Too many tries. Wait a minute and try again.',
    AuthError.offline =>
      "Can't reach the server. Check your connection and try again.",
    AuthError.server => 'Something went wrong on the server. Try again later.',
    AuthError.storage => "Couldn't save on this device. Try again.",
  };

  @override
  bool operator ==(Object other) =>
      other is AuthFailure && other.error == error;

  @override
  int get hashCode => error.hashCode;
}
