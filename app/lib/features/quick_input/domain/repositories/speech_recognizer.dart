import '../../../../core/result/result.dart';
import '../value_objects/quick_input_failure.dart';
import '../value_objects/speech_update.dart';

/// Turns speech into text on the phone (ARCHITECTURE.md §8). Behind an
/// interface so Whisper can replace the platform recognizer later.
abstract interface class SpeechRecognizer {
  /// Listens until the speaker pauses or [stop] is called: what's heard so
  /// far, then one final update, then done. Asks for the microphone the
  /// first time. A failure ends the stream.
  Stream<Result<SpeechUpdate, QuickInputFailure>> listen();

  /// Ends the current listen; its final update still comes.
  Future<void> stop();
}
