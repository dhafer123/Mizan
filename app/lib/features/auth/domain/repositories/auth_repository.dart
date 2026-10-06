import '../../../../core/result/result.dart';
import '../entities/account.dart';
import '../value_objects/auth_failure.dart';
import '../value_objects/credentials.dart';

/// The account this phone is signed in to, and the server calls that change
/// it. Tokens are the implementation's business; the domain never sees them.
abstract interface class AuthRepository {
  /// The current account (null when signed out), then every change: sign-in,
  /// sign-out, and the server ending the session (e.g. after a password
  /// change elsewhere). A storage failure is an [AuthFailure] error event.
  Stream<Account?> watchAccount();

  /// Creates an account and signs this phone in to it.
  Future<Result<Account, AuthFailure>> signUp(Credentials credentials);

  Future<Result<Account, AuthFailure>> logIn(Credentials credentials);

  /// Signs out on this phone even when the server can't be reached.
  Future<Result<void, AuthFailure>> logOut();
}
