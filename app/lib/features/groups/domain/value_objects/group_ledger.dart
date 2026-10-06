import 'package:freezed_annotation/freezed_annotation.dart';

import '../entities/settlement.dart';
import '../entities/shared_expense.dart';

part 'group_ledger.freezed.dart';

/// A group's live rows that move money: what its balances come from.
@freezed
abstract class GroupLedger with _$GroupLedger {
  const GroupLedger._();

  const factory GroupLedger({
    required List<SharedExpense> expenses,

    /// Newest first.
    required List<Settlement> settlements,
  }) = _GroupLedger;

  /// Whether a reversing settlement already cancels [settlementId].
  bool isReversed(String settlementId) =>
      settlements.any((s) => s.reversesId == settlementId);
}
