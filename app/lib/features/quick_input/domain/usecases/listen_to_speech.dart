import '../../../../core/result/result.dart';
import '../repositories/speech_recognizer.dart';
import '../value_objects/quick_input_failure.dart';
import '../value_objects/speech_update.dart';

/// Listens for one phrase: what's heard so far, then the final text.
class ListenToSpeech {
  const ListenToSpeech(this._recognizer);

  final SpeechRecognizer _recognizer;

  Stream<Result<SpeechUpdate, QuickInputFailure>> call() =>
      _recognizer.listen();
}
