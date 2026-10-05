import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';

part 'settlement.freezed.dart';

/// A payment from one member to another to settle debts.
///
/// Settlements are insert-only: never edited or deleted. A mistake is undone
/// by a reversing settlement (see [Settlement.reversal]).
@freezed
abstract class Settlement with _$Settlement {
  const factory Settlement({
    required String id,
    required String groupId,
    required String fromMemberId,
    required String toMemberId,
    required Money amount,
    required DateTime date,

    /// Set when this settlement cancels the one with this id.
    String? reversesId,
  }) = _Settlement;

  /// The settlement that cancels [original]: the same amount flowing back the
  /// other way, so the two add up to nothing in every balance.
  factory Settlement.reversal(
    Settlement original, {
    required String id,
    required DateTime date,
  }) => Settlement(
    id: id,
    groupId: original.groupId,
    fromMemberId: original.toMemberId,
    toMemberId: original.fromMemberId,
    amount: original.amount,
    date: date,
    reversesId: original.id,
  );
}
