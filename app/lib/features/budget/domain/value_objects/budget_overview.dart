import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/clock/year_month.dart';
import '../../../../core/money/money.dart';
import 'category_budget.dart';

part 'budget_overview.freezed.dart';

/// A month's spending against its budget, overall and per category. Computed
/// from rows, never stored.
@freezed
abstract class BudgetOverview with _$BudgetOverview {
  const factory BudgetOverview({
    required YearMonth month,
    required Money spent,

    /// The overall limit in force this month; null for none.
    Money? totalLimit,

    /// The active categories, then archived or unknown ones that have
    /// spending this month. Their `spent` add up to [spent].
    required List<CategoryBudget> categories,
  }) = _BudgetOverview;

  const BudgetOverview._();

  /// What is left of the overall limit; negative when over. Null without one.
  Money? get totalLeft => totalLimit == null ? null : totalLimit! - spent;

  bool get isOver => totalLeft?.isNegative ?? false;

  /// Whole percent of the overall limit spent, rounded down.
  int? get usedPercent => totalLimit == null
      ? null
      : spent.minorUnits * 100 ~/ totalLimit!.minorUnits;
}
