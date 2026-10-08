import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/budget/domain/repositories/alert_log.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_error.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_failure.dart';
import 'package:mizan/features/budget/domain/value_objects/sent_alert.dart';

/// [AlertLog] in memory. Set [failure] to make every call fail.
class FakeAlertLog implements AlertLog {
  FakeAlertLog([List<SentAlert> sent = const []]) : sent = [...sent];

  final List<SentAlert> sent;
  BudgetError? failure;

  @override
  Future<Result<List<SentAlert>, BudgetFailure>> sentSince(DateTime day) async {
    if (failure case final error?) return Err(BudgetFailure(error));
    return Ok([
      for (final s in sent)
        if (!s.sentOn.isBefore(day)) s,
    ]);
  }

  @override
  Future<Result<void, BudgetFailure>> record(SentAlert alert) async {
    if (failure case final error?) return Err(BudgetFailure(error));
    sent.add(alert);
    return const Ok(null);
  }
}
