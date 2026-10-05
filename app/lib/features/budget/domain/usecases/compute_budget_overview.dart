import '../../../../core/clock/year_month.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../expenses/domain/entities/category.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../entities/budget.dart';
import '../value_objects/budget_overview.dart';
import '../value_objects/category_budget.dart';

/// A month's spending against its budget, overall and per category.
///
/// - The overall limit is the one from the latest budget set in [month] or
///   before it.
/// - Each category's limit is its standing `monthlyLimit`.
/// - Lines: every active category (in the order given), then archived ones
///   with spending this month, then one line (category null) for spending
///   under categories this device doesn't know. Their spending adds up to
///   the month's total.
class ComputeBudgetOverview {
  const ComputeBudgetOverview();

  BudgetOverview call({
    required YearMonth month,
    required Currency currency,
    required List<Budget> budgets,
    required List<Category> categories,

    /// May include other months; only [month]'s count.
    required List<Expense> expenses,
  }) {
    final zero = Money.zero(currency);
    final inMonth = expenses.where((e) => month.contains(e.date)).toList();

    final spentBy = <String, Money>{};
    for (final expense in inMonth) {
      spentBy[expense.categoryId] =
          (spentBy[expense.categoryId] ?? zero) + expense.amount;
    }

    final known = {for (final c in categories) c.id};
    final unknownSpent = Money.sum([
      for (final MapEntry(key: id, value: spent) in spentBy.entries)
        if (!known.contains(id)) spent,
    ], currency);

    final lines = [
      for (final c in categories.where((c) => !c.archived))
        CategoryBudget(
          category: c,
          spent: spentBy[c.id] ?? zero,
          limit: c.monthlyLimit,
        ),
      for (final c in categories.where((c) => c.archived))
        if (spentBy[c.id] case final spent?)
          CategoryBudget(category: c, spent: spent, limit: c.monthlyLimit),
      if (spentBy.keys.any((id) => !known.contains(id)))
        CategoryBudget(category: null, spent: unknownSpent),
    ];

    return BudgetOverview(
      month: month,
      spent: Money.sum(inMonth.map((e) => e.amount), currency),
      totalLimit: budgetFor(month, budgets)?.totalLimit,
      categories: List.unmodifiable(lines),
    );
  }

  /// The budget in force in [month]: the latest one set in it or before it.
  static Budget? budgetFor(YearMonth month, List<Budget> budgets) {
    Budget? best;
    for (final budget in budgets) {
      if (budget.month.compareTo(month) > 0) continue;
      if (best == null ||
          budget.month.compareTo(best.month) > 0 ||
          (budget.month == best.month && budget.id.compareTo(best.id) > 0)) {
        best = budget;
      }
    }
    return best;
  }
}
