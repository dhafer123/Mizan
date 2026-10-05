import '../../../../core/money/money.dart';
import '../../../../core/result/result.dart';
import '../value_objects/simplify_error.dart';
import '../value_objects/simplify_failure.dart';
import '../value_objects/transfer.dart';

/// Turns group balances into a short list of payments that settles everyone.
///
/// Greedy: the biggest debtor pays the biggest creditor as much as both
/// allow, until all balances are zero. Every step zeroes at least one member
/// and the last step zeroes two, so with n non-zero balances there are at
/// most n − 1 transfers. Nobody both pays and receives. Ties go to the
/// lowest member id, so every device suggests the same transfers.
class SimplifyDebts {
  const SimplifyDebts();

  Result<List<Transfer>, SimplifyFailure> call(Map<String, Money> balances) {
    if (balances.isEmpty) return const Ok([]);

    final currency = balances.values.first.currency;
    if (balances.values.any((m) => m.currency != currency)) {
      return const Err(SimplifyFailure(SimplifyError.currencyMismatch));
    }
    if (!Money.sum(balances.values, currency).isZero) {
      return const Err(SimplifyFailure(SimplifyError.notBalanced));
    }

    // What each debtor still owes and each creditor is still owed (> 0).
    final owes = <String, int>{
      for (final MapEntry(key: id, value: m) in balances.entries)
        if (m.isNegative) id: -m.minorUnits,
    };
    final owed = <String, int>{
      for (final MapEntry(key: id, value: m) in balances.entries)
        if (m.isPositive) id: m.minorUnits,
    };

    final transfers = <Transfer>[];
    while (owes.isNotEmpty) {
      final debtor = _largest(owes);
      final creditor = _largest(owed);
      final amount = owes[debtor]! < owed[creditor]!
          ? owes[debtor]!
          : owed[creditor]!;

      transfers.add(
        Transfer(
          fromMemberId: debtor,
          toMemberId: creditor,
          amount: Money(amount, currency),
        ),
      );
      _reduce(owes, debtor, amount);
      _reduce(owed, creditor, amount);
    }
    return Ok(List.unmodifiable(transfers));
  }

  /// The id with the largest value; ties go to the lowest id.
  static String _largest(Map<String, int> amounts) {
    late String best;
    int? bestAmount;
    for (final MapEntry(key: id, value: amount) in amounts.entries) {
      if (bestAmount == null ||
          amount > bestAmount ||
          (amount == bestAmount && id.compareTo(best) < 0)) {
        best = id;
        bestAmount = amount;
      }
    }
    return best;
  }

  static void _reduce(Map<String, int> amounts, String id, int by) {
    final left = amounts[id]! - by;
    if (left == 0) {
      amounts.remove(id);
    } else {
      amounts[id] = left;
    }
  }
}
