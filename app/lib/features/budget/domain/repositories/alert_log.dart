import '../../../../core/result/result.dart';
import '../value_objects/budget_failure.dart';
import '../value_objects/sent_alert.dart';

/// Which budget alerts this phone has sent. Local only, never synced.
abstract interface class AlertLog {
  /// The alerts sent on or after the calendar [day].
  Future<Result<List<SentAlert>, BudgetFailure>> sentSince(DateTime day);

  Future<Result<void, BudgetFailure>> record(SentAlert alert);
}
