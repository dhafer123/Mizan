import '../entities/account.dart';
import '../repositories/auth_repository.dart';

/// The signed-in account, or null in local-only mode, and every change.
class WatchAccount {
  const WatchAccount(this._repository);

  final AuthRepository _repository;

  Stream<Account?> call() => _repository.watchAccount();
}
