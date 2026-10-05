import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/result/result.dart';
import '../entities/settlement.dart';
import '../entities/shared_expense.dart';
import '../value_objects/balance_error.dart';
import '../value_objects/balance_failure.dart';

/// Each member's balance in a group: positive means the group owes them,
/// negative means they owe the group.
///
/// balance = paid for expenses − own shares
///         + settlements paid − settlements received
///
/// The balances always sum to zero. Balances are never stored; call this on
/// the group's live rows (no tombstones) whenever they are needed.
class ComputeBalances {
  const ComputeBalances();

  /// Returns balances sorted by member id. Every id in [memberIds] is
  /// included (zero if untouched), plus anyone named by a row.
  Result<Map<String, Money>, BalanceFailure> call({
    required Currency currency,
    required Iterable<SharedExpense> expenses,
    required Iterable<Settlement> settlements,
    Set<String> memberIds = const {},
  }) {
    final totals = <String, int>{for (final id in memberIds) id: 0};
    void add(String memberId, int minorUnits) =>
        totals[memberId] = (totals[memberId] ?? 0) + minorUnits;

    for (final expense in expenses) {
      Err<Map<String, Money>, BalanceFailure> fail(BalanceError error) =>
          Err(BalanceFailure(error, recordId: expense.id));

      if (expense.amount.currency != currency ||
          expense.shares.values.any((s) => s.currency != currency)) {
        return fail(BalanceError.currencyMismatch);
      }
      if (Money.sum(expense.shares.values, currency) != expense.amount) {
        return fail(BalanceError.sharesDoNotMatchAmount);
      }
      add(expense.payerId, expense.amount.minorUnits);
      for (final MapEntry(key: memberId, value: share)
          in expense.shares.entries) {
        add(memberId, -share.minorUnits);
      }
    }

    for (final settlement in settlements) {
      Err<Map<String, Money>, BalanceFailure> fail(BalanceError error) =>
          Err(BalanceFailure(error, recordId: settlement.id));

      if (settlement.amount.currency != currency) {
        return fail(BalanceError.currencyMismatch);
      }
      if (!settlement.amount.isPositive ||
          settlement.fromMemberId == settlement.toMemberId) {
        return fail(BalanceError.invalidSettlement);
      }
      add(settlement.fromMemberId, settlement.amount.minorUnits);
      add(settlement.toMemberId, -settlement.amount.minorUnits);
    }

    final ids = totals.keys.toList()..sort();
    return Ok(
      Map.unmodifiable({
        for (final id in ids) id: Money(totals[id]!, currency),
      }),
    );
  }
}
