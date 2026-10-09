import '../../../../core/result/result.dart';
import '../value_objects/beta_failure.dart';
import '../value_objects/feedback_message.dart';
import '../value_objects/usage_report.dart';

/// The server's anonymous beta endpoints. Nothing sent here carries the
/// account.
abstract interface class BetaRepository {
  Future<Result<void, BetaFailure>> sendFeedback(FeedbackMessage feedback);

  /// Replaces what the server has for the report's days.
  Future<Result<void, BetaFailure>> sendUsage(UsageReport report);
}
