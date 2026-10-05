import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';
import '../value_objects/split.dart';

part 'shared_expense.freezed.dart';

/// An expense paid by one member for some of the group.
///
/// [shares] is what `ComputeShares` produced from [split] when the expense
/// was saved. It is stored rather than recomputed, so a later change to the
/// rounding rules can never move old balances. The shares add up to
/// [amount]; the payer may or may not be among them.
@freezed
abstract class SharedExpense with _$SharedExpense {
  const factory SharedExpense({
    required String id,
    required String groupId,
    required String payerId,
    required Money amount,
    required DateTime date,
    required Split split,
    required Map<String, Money> shares,
    String? categoryId,
  }) = _SharedExpense;
}
