import '../../../../core/result/result.dart';
import '../entities/account.dart';
import '../repositories/auth_repository.dart';
import '../value_objects/auth_failure.dart';
import 'validate_credentials.dart';

/// Signs this phone in to an existing account.
class LogIn {
  const LogIn(this._repository, this._validate);

  final AuthRepository _repository;
  final ValidateCredentials _validate;

  Future<Result<Account, AuthFailure>> call({
    required String email,
    required String password,
  }) async {
    final validated = _validate(
      email: email,
      password: password,
      newAccount: false,
    );
    return switch (validated) {
      Ok(:final value) => _repository.logIn(value),
      Err(:final failure) => Err(failure),
    };
  }
}
