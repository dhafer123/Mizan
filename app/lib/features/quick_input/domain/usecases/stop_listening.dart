import '../repositories/speech_recognizer.dart';

/// Ends the current listen early; its final text still comes.
class StopListening {
  const StopListening(this._recognizer);

  final SpeechRecognizer _recognizer;

  Future<void> call() => _recognizer.stop();
}
