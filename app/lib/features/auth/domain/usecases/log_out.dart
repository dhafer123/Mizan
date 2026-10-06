import '../../../../core/result/result.dart';
import '../repositories/auth_repository.dart';
import '../value_objects/auth_failure.dart';

/// Signs this phone out: back to local-only mode. Local data stays.
class LogOut {
  const LogOut(this._repository);

  final AuthRepository _repository;

  Future<Result<void, AuthFailure>> call() => _repository.logOut();
}
