import '../../../../core/result/result.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_error.dart';
import '../value_objects/group_failure.dart';
import 'compute_balances.dart';

/// This account leaves a group, which then disappears from this phone.
///
/// Only once this account's balance is 0, so nobody is left owed. That is
/// checked here first (no network needed to say no), and again by the
/// server, which has every phone's rows. Needs a connection.
class LeaveGroup {
  const LeaveGroup(
    this._repository, [
    this._computeBalances = const ComputeBalances(),
  ]);

  final GroupRepository _repository;
  final ComputeBalances _computeBalances;

  Future<Result<void, GroupFailure>> call({
    required String groupId,
    required String? accountId,
  }) async {
    Err<void, GroupFailure> fail(GroupError e) => Err(GroupFailure(e));

    if (accountId == null) return fail(GroupError.signedOut);
    final group = await _repository.getGroup(groupId);
    if (group case Err(:final failure)) return Err(failure);
    final currency = group.valueOrNull?.currency;
    if (currency == null) return fail(GroupError.notFound);

    final members = await _repository.getMembers(groupId);
    if (members case Err(:final failure)) return Err(failure);
    final me = members.valueOrNull!
        .where((m) => m.userId == accountId)
        .firstOrNull;
    if (me == null) return fail(GroupError.notFound);

    final ledger = await _repository.getLedger(groupId);
    if (ledger case Err(:final failure)) return Err(failure);
    final balances = _computeBalances(
      currency: currency,
      expenses: ledger.valueOrNull!.expenses,
      settlements: ledger.valueOrNull!.settlements,
      memberIds: {me.id},
    );
    // Rows that can't be added up are left to the server's own check.
    if (balances case Ok(:final value) when !value[me.id]!.isZero) {
      return fail(GroupError.balanceNotZero);
    }
    return _repository.leave(groupId);
  }
}
