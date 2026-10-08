import '../domain/value_objects/quick_parse.dart';

/// Where the quick input sheet is: listening, reading, confirming, or
/// stopped by a failure.
sealed class QuickInputState {
  const QuickInputState();
}

/// The microphone is on; [heard] is the text so far.
class QuickListening extends QuickInputState {
  const QuickListening([this.heard = '']);

  final String heard;
}

/// Typing instead of speaking.
class QuickTyping extends QuickInputState {
  const QuickTyping();
}

/// Reading the phrase (rules, then maybe the assistant).
class QuickReading extends QuickInputState {
  const QuickReading(this.text);

  final String text;
}

/// What was read, waiting for the user to check and save it.
class QuickConfirming extends QuickInputState {
  const QuickConfirming(
    this.parse, {
    required this.fromVoice,
    this.sinceSpeech,
  });

  final QuickParse parse;
  final bool fromVoice;

  /// Started when the final speech arrived: the sheet stops it once the
  /// items are on screen (the time recorded in METRICS.md).
  final Stopwatch? sinceSpeech;
}

/// Listening failed; [message] says why.
class QuickFailed extends QuickInputState {
  const QuickFailed(this.message);

  final String message;
}
