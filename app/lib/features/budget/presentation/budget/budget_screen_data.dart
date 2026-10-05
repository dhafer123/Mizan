import '../../domain/value_objects/budget_overview.dart';
import '../../domain/value_objects/money_available.dart';

/// What the budget screen shows for one month.
class BudgetScreenData {
  const BudgetScreenData({
    required this.overview,
    required this.available,
    required this.hasIncome,
    required this.isCurrentMonth,
  });

  final BudgetOverview overview;
  final MoneyAvailable available;

  /// Whether any income source exists (to prompt for one if not).
  final bool hasIncome;

  /// The next income is only shown for the current month.
  final bool isCurrentMonth;
}
