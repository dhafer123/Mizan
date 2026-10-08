import '../../expenses/domain/value_objects/expense_source.dart';
import '../domain/value_objects/quick_parse.dart';

/// Where the quick input sheet is: listening, typing, reading a phrase or
/// a receipt, confirming, or stopped by a failure.
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

/// Reading a receipt photo.
class QuickScanning extends QuickInputState {
  const QuickScanning();
}

/// What was read, waiting for the user to check and save it.
class QuickConfirming extends QuickInputState {
  const QuickConfirming(this.parse, {required this.source, this.sinceSpeech});

  final QuickParse parse;

  /// Voice, typed (manual) or a receipt: saved with the expenses.
  final ExpenseSource source;

  /// Started when the final speech arrived: the sheet stops it once the
  /// items are on screen (the time recorded in METRICS.md).
  final Stopwatch? sinceSpeech;
}

/// Listening or a receipt failed; [message] says why.
class QuickFailed extends QuickInputState {
  const QuickFailed(this.message, {this.receipt = false});

  final String message;

  /// It was a receipt: trying again takes another photo.
  final bool receipt;
}
