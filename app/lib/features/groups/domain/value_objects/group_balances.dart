import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';

part 'group_balances.freezed.dart';

/// Where someone stands in a group.
enum Standing {
  /// The group owes them.
  owed,

  /// They owe the group.
  owes,
  settled,
}

/// Every member's balance in one group: positive means the group owes them,
/// negative means they owe. Sums to zero.
@freezed
abstract class GroupBalances with _$GroupBalances {
  const GroupBalances._();

  const factory GroupBalances(Map<String, Money> byMember) = _GroupBalances;

  /// [memberId]'s standing and the amount (never negative); settled with a
  /// zero amount when they have no balance.
  (Standing, Money)? of(String memberId) {
    final balance = byMember[memberId];
    if (balance == null) return null;
    if (balance.isPositive) return (Standing.owed, balance);
    if (balance.isNegative) return (Standing.owes, -balance);
    return (Standing.settled, balance);
  }
}
