import '../../../../core/clock/calendar_day.dart';
import '../value_objects/alert_type.dart';
import '../value_objects/budget_alert.dart';
import '../value_objects/sent_alert.dart';

/// Which of the alerts that hold now to send (ADR 0013):
///
/// - **At most one a day per type.** A type already sent today sends
///   nothing more until tomorrow.
/// - **Once per situation.** A category's limit alert once a month, each
///   unusual expense once. A run-out alert once per payday, and again only
///   if the run-out date moves earlier than every warning before it.
/// - **The most pressing of each type:** the category with the highest
///   share used, the expense furthest above its usual cost.
///
/// The result is in [AlertType] order.
class SelectAlertsToSend {
  const SelectAlertsToSend();

  List<BudgetAlert> call({
    required DateTime today,
    required List<BudgetAlert> candidates,

    /// At least everything sent in the last 62 days.
    required List<SentAlert> sent,
  }) {
    final day0 = today.calendarDay;
    final picked = <BudgetAlert>[];
    for (final type in AlertType.values) {
      if (sent.any((s) => s.type == type && s.sentOn == day0)) continue;
      final fresh = [
        for (final alert in candidates)
          if (alert.type == type && _isNew(alert, sent)) alert,
      ];
      if (fresh.isEmpty) continue;
      picked.add(fresh.reduce((a, b) => _morePressing(b, a) ? b : a));
    }
    return picked;
  }

  static bool _isNew(BudgetAlert alert, List<SentAlert> sent) {
    final before = sent.where(
      (s) => s.type == alert.type && s.situation == alert.situation,
    );
    return switch (alert) {
      RunOutAlert(:final runOut) => before.every(
        (s) => s.runOut != null && runOut.isBefore(s.runOut!),
      ),
      _ => before.isEmpty,
    };
  }

  /// Whether [a] matters more than [b], both of the same type. Ties keep
  /// the first, so the choice is stable.
  static bool _morePressing(BudgetAlert a, BudgetAlert b) => switch ((a, b)) {
    (final CategoryLimitAlert x, final CategoryLimitAlert y) =>
      x.usedPercent > y.usedPercent,
    (final UnusualSpendingAlert x, final UnusualSpendingAlert y) =>
      // x.amount / x.median > y.amount / y.median, without dividing.
      BigInt.from(x.amount.minorUnits) * BigInt.from(y.median.minorUnits) >
          BigInt.from(y.amount.minorUnits) * BigInt.from(x.median.minorUnits),
    (final RunOutAlert x, final RunOutAlert y) => x.runOut.isBefore(y.runOut),
    _ => false,
  };
}
