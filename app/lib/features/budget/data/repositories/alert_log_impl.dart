import 'package:drift/drift.dart';

import '../../../../app/db/app_database.dart';
import '../../../../core/result/result.dart';
import '../../domain/repositories/alert_log.dart';
import '../../domain/usecases/send_budget_alerts.dart';
import '../../domain/value_objects/budget_error.dart';
import '../../domain/value_objects/budget_failure.dart';
import '../../domain/value_objects/sent_alert.dart';
import '../db/sent_alerts_dao.dart';

/// [AlertLog] on the local drift database. Database errors become
/// [BudgetFailure]s; nothing is thrown past this class.
class AlertLogImpl implements AlertLog {
  const AlertLogImpl(this._dao);

  final SentAlertsDao _dao;

  static const _storage = BudgetFailure(BudgetError.storage);

  /// Kept a little longer than the use case reads back.
  static const _keep = Duration(days: SendBudgetAlerts.lookbackDays + 30);

  @override
  Future<Result<List<SentAlert>, BudgetFailure>> sentSince(DateTime day) async {
    try {
      final rows = await _dao.sentSince(day);
      return Ok([
        for (final row in rows)
          SentAlert(
            type: row.type,
            situation: row.situation,
            sentOn: row.sentOn.toUtc(),
            runOut: row.runOut?.toUtc(),
          ),
      ]);
    } on Object {
      return const Err(_storage);
    }
  }

  @override
  Future<Result<void, BudgetFailure>> record(SentAlert alert) async {
    try {
      await _dao.record(
        SentAlertsCompanion.insert(
          type: alert.type,
          situation: alert.situation,
          sentOn: alert.sentOn.toUtc(),
          runOut: Value(alert.runOut?.toUtc()),
        ),
        keep: _keep,
      );
      return const Ok(null);
    } on Object {
      return const Err(_storage);
    }
  }
}
