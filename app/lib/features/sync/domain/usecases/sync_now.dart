import '../../../../core/clock/clock.dart';
import '../../../../core/result/result.dart';
import '../repositories/sync_repository.dart';
import '../value_objects/sync_failure.dart';
import '../value_objects/sync_report.dart';

/// One sync: push queued changes, then pull everything new (ARCHITECTURE.md
/// §6). Pushing first means the pull brings back the merged result of this
/// phone's own changes.
class SyncNow {
  const SyncNow(this._repository, this._clock);

  final SyncRepository _repository;
  final Clock _clock;

  Future<Result<(SyncReport, DateTime), SyncFailure>> call({
    required String accountId,
  }) async {
    final pushed = await _repository.push();
    if (pushed case Err(:final failure)) return Err(failure);
    final (:accepted, :rejected) = pushed.valueOrNull!;

    final pulled = await _repository.pull(accountId: accountId);
    return pulled.map(
      (count) => (
        SyncReport(pushed: accepted, rejected: rejected, pulled: count),
        _clock.now(),
      ),
    );
  }
}
