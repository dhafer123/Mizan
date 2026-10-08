import '../../../../core/clock/calendar_day.dart';
import '../../../../core/clock/clock.dart';
import '../../../../core/result/result.dart';
import '../repositories/alert_log.dart';
import '../repositories/alert_notifier.dart';
import '../value_objects/budget_alert.dart';
import '../value_objects/budget_failure.dart';
import '../value_objects/sent_alert.dart';
import 'select_alerts_to_send.dart';

/// Sends the alerts that are due (see [SelectAlertsToSend]) as
/// notifications, and logs each one shown.
///
/// One that couldn't be shown (notifications off) isn't logged, so it is
/// tried again on the next check. Checks run one at a time, so two quick
/// changes can't both send the same alert.
class SendBudgetAlerts {
  SendBudgetAlerts(
    this._log,
    this._notifier,
    this._clock, {
    SelectAlertsToSend select = const SelectAlertsToSend(),
  }) : _select = select;

  final AlertLog _log;
  final AlertNotifier _notifier;
  final Clock _clock;
  final SelectAlertsToSend _select;

  /// How far back the log is read: covers a payday 60 days out and a
  /// whole month.
  static const lookbackDays = 62;

  Future<void> _running = Future.value();

  /// The alerts shown.
  Future<Result<List<BudgetAlert>, BudgetFailure>> call(
    List<BudgetAlert> candidates,
  ) {
    final run = _running.then((_) => _send(candidates));
    _running = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<Result<List<BudgetAlert>, BudgetFailure>> _send(
    List<BudgetAlert> candidates,
  ) async {
    if (candidates.isEmpty) return const Ok([]);
    final today = _clock.now().calendarDay;
    final sent = await _log.sentSince(
      today.subtract(const Duration(days: lookbackDays)),
    );
    final List<SentAlert> log;
    switch (sent) {
      case Ok(:final value):
        log = value;
      case Err(:final failure):
        return Err(failure);
    }

    final shown = <BudgetAlert>[];
    for (final alert in _select(
      today: today,
      candidates: candidates,
      sent: log,
    )) {
      if (!await _notifier.show(alert)) continue;
      final recorded = await _log.record(
        SentAlert(
          type: alert.type,
          situation: alert.situation,
          sentOn: today,
          runOut: switch (alert) {
            RunOutAlert(:final runOut) => runOut,
            _ => null,
          },
        ),
      );
      if (recorded case Err(:final failure)) return Err(failure);
      shown.add(alert);
    }
    return Ok(shown);
  }
}
