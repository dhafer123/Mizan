import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/clock/year_month.dart';
import '../../../../core/money/money.dart';
import 'alert_type.dart';
import 'next_income.dart';

part 'budget_alert.freezed.dart';

/// A warning about the budget, worked out from rows. Never stored: only
/// that it was sent is (see `SentAlert`).
@freezed
sealed class BudgetAlert with _$BudgetAlert {
  const BudgetAlert._();

  /// A category has used [usedPercent] (80 or more) of its limit in [month].
  const factory BudgetAlert.categoryLimit({
    required String categoryId,
    required String categoryName,
    required YearMonth month,
    required Money spent,
    required Money limit,
    required int usedPercent,
  }) = CategoryLimitAlert;

  /// Money is expected to run out on [runOut], before [next] pays (or with
  /// no income scheduled at all).
  const factory BudgetAlert.runOut({
    required DateTime runOut,
    NextIncome? next,
  }) = RunOutAlert;

  /// The expense (or my share of a group expense) [expenseId] costs
  /// [amount], more than `ComputeBudgetAlerts.unusualFactor` times
  /// [median], the category's median over the 4 weeks before it.
  const factory BudgetAlert.unusualSpending({
    required String expenseId,
    required String categoryName,
    required DateTime date,
    required Money amount,
    required Money median,
  }) = UnusualSpendingAlert;

  AlertType get type => switch (this) {
    CategoryLimitAlert() => AlertType.categoryLimit,
    RunOutAlert() => AlertType.runOut,
    UnusualSpendingAlert() => AlertType.unusualSpending,
  };

  /// What this alert is about, so it is sent once per situation: a
  /// category in a month, the run-up to one payday, one expense.
  String get situation => switch (this) {
    CategoryLimitAlert(:final categoryId, :final month) =>
      '$categoryId@${month.year}-${month.month}',
    RunOutAlert(:final next) =>
      next == null ? 'no-income' : next.date.toIso8601String(),
    UnusualSpendingAlert(:final expenseId) => expenseId,
  };
}
