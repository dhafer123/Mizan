import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';
import '../../../expenses/domain/entities/expense.dart';
import 'budget_overview.dart';
import 'category_budget.dart';
import 'money_available.dart';

part 'dashboard.freezed.dart';

/// What the home screen shows for the current month. Computed, never stored.
@freezed
abstract class Dashboard with _$Dashboard {
  const factory Dashboard({
    /// Income against spending this month, and the next income.
    required MoneyAvailable available,

    /// Spending against the overall budget and per category.
    required BudgetOverview overview,

    /// Whole days from today to the next income: 0 on payday. Null if
    /// nothing is scheduled.
    int? daysToNextIncome,

    /// The categories with the most spending this month, most first.
    required List<CategoryBudget> topCategories,

    /// Spending in every other category: with [topCategories], adds up to
    /// the month's spending.
    required Money otherSpent,

    /// The newest expenses, newest first.
    required List<Expense> recent,
  }) = _Dashboard;

  const Dashboard._();

  /// Whether nothing was spent this month.
  bool get isEmptyMonth => overview.spent.isZero;

  /// [spent]'s whole percent of the month's spending, rounded to nearest.
  /// 0 when nothing was spent.
  int sharePercent(Money spent) {
    final total = overview.spent.minorUnits;
    return total == 0 ? 0 : (spent.minorUnits * 200 + total) ~/ (total * 2);
  }
}
