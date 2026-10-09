import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/beta/domain/usecases/send_feedback.dart';
import 'package:mizan/features/beta/domain/value_objects/beta_error.dart';
import 'package:mizan/features/beta/domain/value_objects/beta_failure.dart';
import 'package:mizan/features/beta/domain/value_objects/feedback_message.dart';
import 'package:test/test.dart';

import '../../../../support/fake_beta_repository.dart';

void main() {
  late FakeBetaRepository repository;
  late SendFeedback send;

  setUp(() {
    repository = FakeBetaRepository();
    send = SendFeedback(repository, '0.1.0+1');
  });

  Err<void, BetaFailure> failed(BetaError error) => Err(BetaFailure(error));

  test('sends the trimmed message, contact and app version', () async {
    final result = await send(
      message: '  The mic is hard to find \n',
      contact: ' sami@example.com ',
    );

    expect(result, const Ok<void, BetaFailure>(null));
    expect(repository.feedback, [
      const FeedbackMessage(
        message: 'The mic is hard to find',
        contact: 'sami@example.com',
        appVersion: '0.1.0+1',
      ),
    ]);
  });

  test('the contact is optional', () async {
    await send(message: 'Love it');

    expect(repository.feedback.single.contact, '');
  });

  test('a blank message is not sent', () async {
    expect(await send(message: '  \n '), failed(BetaError.emptyMessage));
    expect(repository.feedback, isEmpty);
  });

  test('too long a message or contact is not sent', () async {
    final long = 'x' * (FeedbackMessage.maxLength + 1);
    final longContact = 'x' * (FeedbackMessage.maxContactLength + 1);

    expect(await send(message: long), failed(BetaError.messageTooLong));
    expect(
      await send(message: 'Hi', contact: longContact),
      failed(BetaError.contactTooLong),
    );
    expect(repository.feedback, isEmpty);
  });

  test('a send failure is returned', () async {
    repository.failure = const BetaFailure(BetaError.offline);

    expect(await send(message: 'Hi'), failed(BetaError.offline));
  });
}
