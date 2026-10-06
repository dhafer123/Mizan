import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_share.dart';
import '../value_objects/group_snapshot.dart';
import '../value_objects/my_group_money.dart';
import 'compute_balances.dart';

/// My groups, seen from my own budget (ARCHITECTURE.md §4, `mySpending`):
/// only my share of a shared expense is my spending; what the others owe
/// me (or I owe them) is shown separately and isn't spending. Paying 900
/// rent for three adds 300 to my spending and 600 to "owed to me".
///
/// Only groups in [currency] count: amounts in another currency can't be
/// added to my budget.
class WatchMyGroupMoney {
  const WatchMyGroupMoney(
    this._repository, [
    this._computeBalances = const ComputeBalances(),
  ]);

  final GroupRepository _repository;
  final ComputeBalances _computeBalances;

  /// [accountId] is this phone's account; null (signed out) means no groups.
  Stream<Result<MyGroupMoney, Failure>> call({
    required String? accountId,
    required Currency currency,
  }) => _repository.watchAllGroups().map(
    (groups) => switch (groups) {
      Err(:final failure) => Err(failure),
      Ok(value: final groups) => _mine(groups, accountId, currency),
    },
  );

  Result<MyGroupMoney, Failure> _mine(
    List<GroupSnapshot> groups,
    String? accountId,
    Currency currency,
  ) {
    final shares = <GroupShare>[];
    var owed = Money.zero(currency);
    var owe = Money.zero(currency);
    for (final GroupSnapshot(:group, :members, :ledger) in groups) {
      if (accountId == null || group.currency != currency) continue;
      final me = members.where((m) => m.userId == accountId).firstOrNull;
      if (me == null) continue;

      for (final e in ledger.expenses) {
        final share = e.shares[me.id];
        if (share == null || share.isZero) continue;
        shares.add(
          GroupShare(
            groupId: group.id,
            expenseId: e.id,
            amount: share,
            categoryId: e.categoryId,
            date: e.date,
          ),
        );
      }

      final balances = _computeBalances(
        currency: currency,
        expenses: ledger.expenses,
        settlements: ledger.settlements,
      );
      if (balances case Err(:final failure)) return Err(failure);
      final mine = balances.valueOrNull![me.id];
      if (mine == null) continue;
      if (mine.isPositive) owed += mine;
      if (mine.isNegative) owe -= mine;
    }
    return Ok(MyGroupMoney(shares: shares, owedToMe: owed, iOwe: owe));
  }
}
