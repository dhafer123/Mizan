import '../../../../core/result/result.dart';
import '../entities/account.dart';
import '../repositories/auth_repository.dart';
import '../value_objects/auth_failure.dart';
import 'validate_credentials.dart';

/// Creates a server account and signs this phone in to it. Local data is
/// untouched; it starts syncing once sync exists (task 3.6).
class SignUp {
  const SignUp(this._repository, this._validate);

  final AuthRepository _repository;
  final ValidateCredentials _validate;

  Future<Result<Account, AuthFailure>> call({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final validated = _validate(
      email: email,
      password: password,
      displayName: displayName,
      newAccount: true,
    );
    return switch (validated) {
      Ok(:final value) => _repository.signUp(value),
      Err(:final failure) => Err(failure),
    };
  }
}
