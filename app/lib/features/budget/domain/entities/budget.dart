import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/clock/year_month.dart';
import '../../../../core/money/money.dart';

part 'budget.freezed.dart';

/// The overall spending limit set in [month]. It carries forward: a month
/// uses the latest budget set in it or before it (see `ComputeBudgetOverview`).
///
/// Per-category limits are each category's standing `monthlyLimit`.
@freezed
abstract class Budget with _$Budget {
  const factory Budget({
    required String id,
    required YearMonth month,

    /// Null: no overall limit from this month on.
    Money? totalLimit,
  }) = _Budget;

  const Budget._();

  /// The id of [month]'s budget. It is derived from the month, so two
  /// devices setting October's budget write the same row instead of two
  /// (see docs/decisions/0002-month-budget-ids.md).
  static String idFor(YearMonth month) =>
      'budget-${month.year.toString().padLeft(4, '0')}-'
      '${month.month.toString().padLeft(2, '0')}';
}
