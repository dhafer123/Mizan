import '../../../../core/money/currency.dart';
import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_balances.dart';
import 'compute_balances.dart';

/// A group's balances, recomputed from its expenses and settlements on
/// every change (never stored).
class WatchGroupBalances {
  const WatchGroupBalances(
    this._repository, [
    this._computeBalances = const ComputeBalances(),
  ]);

  final GroupRepository _repository;
  final ComputeBalances _computeBalances;

  /// [memberIds] get a zero balance when no row names them.
  Stream<Result<GroupBalances, Failure>> call(
    String groupId, {
    required Currency currency,
    Set<String> memberIds = const {},
  }) => _repository
      .watchLedger(groupId)
      .map(
        (ledger) => switch (ledger) {
          Err(:final failure) => Err(failure),
          Ok(value: final ledger) => switch (_computeBalances(
            currency: currency,
            expenses: ledger.expenses,
            settlements: ledger.settlements,
            memberIds: memberIds,
          )) {
            Ok(:final value) => Ok(GroupBalances(value)),
            Err(:final failure) => Err(failure),
          },
        },
      );
}
