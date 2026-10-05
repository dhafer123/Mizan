import '../../../../core/clock/calendar_day.dart';
import '../../../../core/clock/year_month.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../expenses/domain/entities/category.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../entities/budget.dart';
import '../entities/income_source.dart';
import '../value_objects/category_budget.dart';
import '../value_objects/dashboard.dart';
import 'compute_budget_overview.dart';
import 'compute_money_available.dart';

/// The home screen for the month [today] falls in: money left, days until
/// the next income, the top categories and the newest expenses.
class ComputeDashboard {
  const ComputeDashboard({
    ComputeBudgetOverview overview = const ComputeBudgetOverview(),
    ComputeMoneyAvailable available = const ComputeMoneyAvailable(),
  }) : _overview = overview,
       _available = available;

  final ComputeBudgetOverview _overview;
  final ComputeMoneyAvailable _available;

  /// How many categories get their own slice; the rest are summed.
  static const topCount = 4;

  /// How many recent expenses are shown.
  static const recentCount = 5;

  Dashboard call({
    required DateTime today,
    required Currency currency,
    required List<Budget> budgets,
    required List<Category> categories,
    required List<IncomeSource> incomes,

    /// The current month's, and any earlier ones to fill [Dashboard.recent]
    /// at the start of a month.
    required List<Expense> expenses,
  }) {
    final month = YearMonth.of(today);
    final overview = _overview(
      month: month,
      currency: currency,
      budgets: budgets,
      categories: categories,
      expenses: expenses,
    );
    final available = _available(
      month: month,
      currency: currency,
      incomes: incomes,
      expenses: expenses,
      today: today,
    );

    final spending = overview.categories.where((l) => l.spent.isPositive);
    final ranked = [...spending]..sort(_mostSpentFirst);
    final top = ranked.take(topCount).toList();

    final recent = [...expenses]
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        // UUIDv7 ids sort by creation time; only for display.
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });

    return Dashboard(
      available: available,
      overview: overview,
      daysToNextIncome: available.next?.date
          .difference(today.calendarDay)
          .inDays,
      topCategories: List.unmodifiable(top),
      otherSpent: Money.sum(
        ranked.skip(topCount).map((l) => l.spent),
        currency,
      ),
      recent: List.unmodifiable(recent.take(recentCount)),
    );
  }

  /// Most spent first; ties by name (unknown categories last), so the order
  /// is stable.
  static int _mostSpentFirst(CategoryBudget a, CategoryBudget b) {
    final bySpent = b.spent.compareTo(a.spent);
    if (bySpent != 0) return bySpent;
    final (x, y) = (a.category, b.category);
    if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
    final byName = x.name.compareTo(y.name);
    return byName != 0 ? byName : x.id.compareTo(y.id);
  }
}
