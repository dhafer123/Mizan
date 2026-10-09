import '../../../../core/result/result.dart';
import '../entities/usage_sharing.dart';
import '../value_objects/beta_failure.dart';

/// Whether this device shares usage counts. Null means it doesn't.
abstract interface class UsageSharingRepository {
  Future<Result<UsageSharing?, BetaFailure>> load();

  Future<Result<void, BetaFailure>> save(UsageSharing? sharing);
}
