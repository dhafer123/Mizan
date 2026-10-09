import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/beta/domain/repositories/beta_repository.dart';
import 'package:mizan/features/beta/domain/value_objects/beta_failure.dart';
import 'package:mizan/features/beta/domain/value_objects/feedback_message.dart';
import 'package:mizan/features/beta/domain/value_objects/usage_report.dart';

/// A [BetaRepository] that records what was sent.
class FakeBetaRepository implements BetaRepository {
  final feedback = <FeedbackMessage>[];
  final reports = <UsageReport>[];

  /// When set, every send fails with this.
  BetaFailure? failure;

  @override
  Future<Result<void, BetaFailure>> sendFeedback(
    FeedbackMessage feedback,
  ) async {
    if (failure case final failure?) return Err(failure);
    this.feedback.add(feedback);
    return const Ok(null);
  }

  @override
  Future<Result<void, BetaFailure>> sendUsage(UsageReport report) async {
    if (failure case final failure?) return Err(failure);
    reports.add(report);
    return const Ok(null);
  }
}
