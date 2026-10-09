import '../../../../core/result/failure.dart';
import 'beta_error.dart';
import 'feedback_message.dart';

class BetaFailure extends Failure {
  const BetaFailure(this.error);

  final BetaError error;

  @override
  String get message => switch (error) {
    BetaError.emptyMessage => 'Write something first.',
    BetaError.messageTooLong =>
      'Keep it under ${FeedbackMessage.maxLength} characters.',
    BetaError.contactTooLong => 'That contact is too long.',
    BetaError.offline => "Couldn't reach the server. Check your connection.",
    BetaError.tooManyRequests => 'Too many messages for now. Try again later.',
    BetaError.server => 'Something went wrong on the server. Try again.',
    BetaError.storage => "Couldn't save on this device. Try again.",
  };

  @override
  bool operator ==(Object other) =>
      other is BetaFailure && other.error == error;

  @override
  int get hashCode => error.hashCode;
}
