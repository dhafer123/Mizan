import '../../../../core/clock/calendar_day.dart';
import '../../../../core/clock/clock.dart';
import '../../../../core/ids/id_generator.dart';
import '../../../../core/result/result.dart';
import '../entities/usage_sharing.dart';
import '../repositories/usage_sharing_repository.dart';
import '../value_objects/beta_failure.dart';

/// Turns sharing anonymous usage counts on or off. Turning it on makes a new
/// random install id (give it a `RandomIdGenerator`, not time-based ids);
/// turning it off forgets it.
class SetUsageSharing {
  const SetUsageSharing(this._repository, this._ids, this._clock);

  final UsageSharingRepository _repository;
  final IdGenerator _ids;
  final Clock _clock;

  Future<Result<void, BetaFailure>> call({required bool enabled}) async {
    if (!enabled) return _repository.save(null);
    switch (await _repository.load()) {
      case Ok(value: _?):
        return const Ok(null); // Already on: keep the same install id.
      case Ok():
        return _repository.save(
          UsageSharing(
            installId: _ids.newId(),
            since: _clock.now().calendarDay,
          ),
        );
      case Err(:final failure):
        return Err(failure);
    }
  }
}
