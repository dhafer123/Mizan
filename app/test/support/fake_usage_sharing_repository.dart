import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/beta/domain/entities/usage_sharing.dart';
import 'package:mizan/features/beta/domain/repositories/usage_sharing_repository.dart';
import 'package:mizan/features/beta/domain/value_objects/beta_failure.dart';

/// An in-memory [UsageSharingRepository]. Starts off unless given [sharing].
class FakeUsageSharingRepository implements UsageSharingRepository {
  FakeUsageSharingRepository([this.sharing]);

  UsageSharing? sharing;

  /// When set, [load] fails with this.
  BetaFailure? loadFailure;

  /// When set, [save] fails with this.
  BetaFailure? saveFailure;

  @override
  Future<Result<UsageSharing?, BetaFailure>> load() async =>
      switch (loadFailure) {
        final failure? => Err(failure),
        null => Ok(sharing),
      };

  @override
  Future<Result<void, BetaFailure>> save(UsageSharing? sharing) async {
    if (saveFailure case final failure?) return Err(failure);
    this.sharing = sharing;
    return const Ok(null);
  }
}
