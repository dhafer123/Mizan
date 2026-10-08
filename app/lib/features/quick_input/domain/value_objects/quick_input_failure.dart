import '../../../../core/result/failure.dart';
import 'quick_input_error.dart';

class QuickInputFailure extends Failure {
  const QuickInputFailure(this.error);

  final QuickInputError error;

  @override
  String get message => switch (error) {
    QuickInputError.micUnavailable =>
      "Mizan can't use the microphone. Allow it in the phone's settings, "
          'or type instead.',
    QuickInputError.speechFailed => "Couldn't hear that. Try again.",
    QuickInputError.nothingHeard => "Didn't catch anything. Try again.",
    QuickInputError.modelNotInstalled =>
      'The assistant is not downloaded. Get it in Settings.',
    QuickInputError.downloadFailed =>
      "The download didn't finish. Check the connection and try again.",
    QuickInputError.llmFailed => "The assistant couldn't read that.",
    QuickInputError.llmInvalid => "The assistant's answer didn't make sense.",
  };

  @override
  bool operator ==(Object other) =>
      other is QuickInputFailure && other.error == error;

  @override
  int get hashCode => error.hashCode;
}
