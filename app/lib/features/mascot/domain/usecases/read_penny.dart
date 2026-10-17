import '../../../budget/domain/usecases/forecast_run_out.dart';
import '../../../budget/domain/value_objects/budget_alert.dart';
import '../../../budget/domain/value_objects/next_income.dart';
import '../../../budget/domain/value_objects/run_out_forecast.dart';
import '../value_objects/penny_mood.dart';
import '../value_objects/penny_reason.dart';
import '../value_objects/penny_state.dart';

/// Penny's mood on Home, from the same facts as the budget alerts
/// (`ComputeBudgetAlerts`) and the forecast. The most pressing reason wins:
///
/// 1. the money runs out before payday: worried;
/// 2. a category over its limit (the most over first): worried;
/// 3. an unusually big expense (the biggest): surprised;
/// 4. a category at 80% or more (the fullest): worried;
/// 5. offline: sleepy;
/// 6. no income set up: calm;
/// 7. nothing spent this month: calm;
/// 8. too little history to forecast: calm;
/// 9. otherwise the money lasts to payday (or the horizon): happy.
///
/// Reactions to what the user just did (an expense saved, setup finished)
/// are the presentation's: they last a few seconds, then this comes back.
class ReadPenny {
  const ReadPenny();

  PennyState call({
    required List<BudgetAlert> alerts,
    required RunOutForecast forecast,
    NextIncome? next,
    required bool hasIncome,
    required bool spentThisMonth,
    bool offline = false,
  }) {
    PennyState worried(PennyReason reason) =>
        PennyState(mood: PennyMood.worried, reason: reason);

    final runOut = alerts.whereType<RunOutAlert>().firstOrNull;
    if (runOut != null) {
      return worried(
        PennyReason.runningOut(
          runOut: runOut.runOut,
          payday: next?.date,
          alreadyOut:
              forecast is ProjectedForecast && runOut.runOut == forecast.today,
        ),
      );
    }

    final limits = alerts.whereType<CategoryLimitAlert>().toList()
      ..sort((a, b) => b.usedPercent.compareTo(a.usedPercent));
    final over = limits.where((a) => a.spent > a.limit).toList()
      ..sort((a, b) => (b.spent - b.limit).compareTo(a.spent - a.limit));
    if (over.firstOrNull case final a?) {
      return worried(
        PennyReason.overLimit(
          category: a.categoryName,
          over: a.spent - a.limit,
        ),
      );
    }

    final unusual = alerts.whereType<UnusualSpendingAlert>().toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    if (unusual.firstOrNull case final a?) {
      return PennyState(
        mood: PennyMood.surprised,
        reason: PennyReason.bigExpense(
          category: a.categoryName,
          amount: a.amount,
        ),
      );
    }

    if (limits.firstOrNull case final a?) {
      return worried(
        PennyReason.nearLimit(
          category: a.categoryName,
          percent: a.usedPercent.clamp(0, 99),
        ),
      );
    }

    PennyState calm(PennyReason reason) =>
        PennyState(mood: PennyMood.calm, reason: reason);

    if (offline) {
      return const PennyState(
        mood: PennyMood.sleepy,
        reason: PennyReason.offline(),
      );
    }
    if (!hasIncome) return calm(const PennyReason.needsIncome());
    if (!spentThisMonth) return calm(const PennyReason.quietMonth());

    switch (forecast) {
      case ForecastNeedsData(:final daysOfData):
        return calm(
          PennyReason.learning(
            daysToGo: (ForecastRunOut.coldStartDays - daysOfData).clamp(
              1,
              ForecastRunOut.coldStartDays,
            ),
          ),
        );
      case ProjectedForecast(:final horizonEnd, :final today):
        // No run-out alert held, so the money lasts to payday (or past the
        // horizon when none is scheduled).
        final payday = next?.date;
        final untilPayday = payday != null && payday.isAfter(today);
        return PennyState(
          mood: PennyMood.happy,
          reason: PennyReason.onTrack(
            until: untilPayday ? payday : horizonEnd,
            untilPayday: untilPayday,
          ),
        );
    }
  }
}
