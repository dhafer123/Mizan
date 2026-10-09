import '../../../../core/result/result.dart';
import '../repositories/usage_sharing_repository.dart';
import '../value_objects/beta_failure.dart';

/// Whether this device shares anonymous usage counts.
class GetUsageSharing {
  const GetUsageSharing(this._repository);

  final UsageSharingRepository _repository;

  Future<Result<bool, BetaFailure>> call() async =>
      (await _repository.load()).map((sharing) => sharing != null);
}
