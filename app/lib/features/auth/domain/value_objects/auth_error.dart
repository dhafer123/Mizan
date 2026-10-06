/// Why signing up, in or out failed.
enum AuthError {
  /// The email is empty or doesn't look like an email.
  invalidEmail,

  /// No password was typed.
  passwordRequired,

  /// A new password shorter than 8 or longer than 128 characters.
  passwordLength,

  /// The server found the new password too easy to guess.
  weakPassword,

  /// A display name over 50 characters.
  displayNameTooLong,

  /// Sign-up with an email that already has an account.
  emailTaken,

  /// Sign-in with a wrong email or password.
  invalidCredentials,

  /// The server is rate-limiting sign-in attempts.
  tooManyAttempts,

  /// The server couldn't be reached (no network, timeout).
  offline,

  /// The server failed or answered with something unexpected.
  server,

  /// Secure storage on the phone failed.
  storage,
}
