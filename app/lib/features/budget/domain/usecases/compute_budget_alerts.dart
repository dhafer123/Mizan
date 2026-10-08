import '../../../../core/clock/calendar_day.dart';
import '../../../../core/money/money.dart';
import '../../../expenses/domain/entities/category.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../groups/domain/value_objects/group_share.dart';
import '../value_objects/budget_alert.dart';
import '../value_objects/budget_overview.dart';
import '../value_objects/next_income.dart';
import '../value_objects/run_out_forecast.dart';

/// Every budget alert that holds right now (ARCHITECTURE.md §4, ADR 0013).
/// Which of them to actually send is `SelectAlertsToSend`'s job.
///
/// - **Category limit:** a category has used [limitPercent]% or more of its
///   monthly limit this month.
/// - **Run-out:** the forecast runs out before the next income, or at all
///   when no income is scheduled.
/// - **Unusual spending:** an expense dated today or yesterday costs more
///   than 2.5× the median of its category's expenses in the
///   [windowDays] days before its date, when there are at least
///   [minComparable] of them. My shares of group expenses count as
///   expenses; one with no category is compared with the others that have
///   none.
class ComputeBudgetAlerts {
  const ComputeBudgetAlerts();

  static const limitPercent = 80;
  static const windowDays = 28;
  static const minComparable = 3;

  /// How many days back (today included) an expense is still checked for
  /// being unusual. Older ones were checked when they were new, or were
  /// added late on purpose.
  static const recentDays = 2;

  List<BudgetAlert> call({
    required DateTime today,
    required BudgetOverview overview,
    required RunOutForecast forecast,
    NextIncome? next,

    /// At least the [windowDays] days before yesterday.
    required List<Expense> expenses,
    List<GroupShare> shares = const [],

    /// For the names in unusual-spending alerts.
    required List<Category> categories,
  }) {
    final day0 = today.calendarDay;
    return [
      for (final line in overview.categories)
        if ((line.category, line.limit, line.usedPercent) case (
          final category?,
          final limit?,
          final percent?,
        ) when percent >= limitPercent)
          BudgetAlert.categoryLimit(
            categoryId: category.id,
            categoryName: category.name,
            month: overview.month,
            spent: line.spent,
            limit: limit,
            usedPercent: percent,
          ),
      if (forecast case ProjectedForecast(
        runOut: final runOut?,
      ) when next == null || runOut.isBefore(next.date))
        BudgetAlert.runOut(runOut: runOut, next: next),
      ..._unusual(day0, expenses, shares, categories),
    ];
  }

  static Iterable<BudgetAlert> _unusual(
    DateTime day0,
    List<Expense> expenses,
    List<GroupShare> shares,
    List<Category> categories,
  ) sync* {
    final spending = <_Spend>[
      for (final e in expenses) _Spend(e.id, e.categoryId, e.date, e.amount),
      for (final s in shares)
        _Spend(s.expenseId, s.categoryId, s.date, s.amount),
    ];
    final names = {for (final c in categories) c.id: c.name};
    final firstChecked = day0.subtract(const Duration(days: recentDays - 1));

    for (final spend in spending) {
      if (spend.date.isBefore(firstChecked) || spend.date.isAfter(day0)) {
        continue;
      }
      final from = spend.date.subtract(const Duration(days: windowDays));
      final usual = [
        for (final other in spending)
          if (other.categoryId == spend.categoryId &&
              other.id != spend.id &&
              !other.date.isBefore(from) &&
              other.date.isBefore(spend.date))
            other.amount.minorUnits,
      ];
      if (usual.length < minComparable) continue;
      final median = _median(usual);
      // Nothing to compare with when the usual cost is 0 (zero shares).
      if (median <= 0) continue;
      // amount > 2.5 × median, in integers.
      if (spend.amount.minorUnits * 2 <= median * 5) continue;
      yield BudgetAlert.unusualSpending(
        expenseId: spend.id,
        categoryName: names[spend.categoryId] ?? 'Other',
        date: spend.date,
        amount: spend.amount,
        median: Money(median, spend.amount.currency),
      );
    }
  }

  /// The middle value; for an even count, the mean of the two middle ones
  /// rounded half up.
  static int _median(List<int> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid] + 1) ~/ 2;
  }
}

class _Spend {
  const _Spend(this.id, this.categoryId, this.date, this.amount);

  final String id;
  final String? categoryId;
  final DateTime date;
  final Money amount;
}
