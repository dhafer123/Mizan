import '../../../../core/money/money.dart';
import '../../domain/value_objects/budget_overview.dart';
import '../../domain/value_objects/money_available.dart';

/// What the budget screen shows for one month.
class BudgetScreenData {
  const BudgetScreenData({
    required this.overview,
    required this.available,
    required this.hasIncome,
    required this.isCurrentMonth,
    required this.owedToMe,
    required this.iOwe,
  });

  final BudgetOverview overview;
  final MoneyAvailable available;

  /// Whether any income source exists (to prompt for one if not).
  final bool hasIncome;

  /// The next income is only shown for the current month.
  final bool isCurrentMonth;

  /// Where I stand in my groups now (not this month's): shown apart, not
  /// spending and not income.
  final Money owedToMe;
  final Money iOwe;
}
