import '../../../../core/result/result.dart';
import '../repositories/sync_repository.dart';
import '../value_objects/sync_failure.dart';

/// Before syncing a signed-in account: the local data becomes that
/// account's. If it was synced with a different account, it is wiped first
/// (decided for 3.6, ADR 0007); local-only data from before the first
/// sign-in is kept and uploaded.
class ClaimLocalData {
  const ClaimLocalData(this._repository);

  final SyncRepository _repository;

  /// Ok(true) when it wiped.
  Future<Result<bool, SyncFailure>> call(String accountId) =>
      _repository.claimFor(accountId);
}
