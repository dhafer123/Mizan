import '../../../../core/result/result.dart';
import '../repositories/beta_repository.dart';
import '../value_objects/beta_error.dart';
import '../value_objects/beta_failure.dart';
import '../value_objects/feedback_message.dart';

/// Sends a feedback message from the beta, anonymously unless [contact]
/// is given. Checks the same limits as the server first.
class SendFeedback {
  const SendFeedback(this._repository, this._appVersion);

  final BetaRepository _repository;
  final String _appVersion;

  Future<Result<void, BetaFailure>> call({
    required String message,
    String contact = '',
  }) async {
    final text = message.trim();
    final replyTo = contact.trim();
    if (text.isEmpty) return const Err(BetaFailure(BetaError.emptyMessage));
    if (text.length > FeedbackMessage.maxLength) {
      return const Err(BetaFailure(BetaError.messageTooLong));
    }
    if (replyTo.length > FeedbackMessage.maxContactLength) {
      return const Err(BetaFailure(BetaError.contactTooLong));
    }
    return _repository.sendFeedback(
      FeedbackMessage(message: text, contact: replyTo, appVersion: _appVersion),
    );
  }
}
