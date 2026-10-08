import 'dart:async';

import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/quick_input/domain/repositories/speech_recognizer.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_failure.dart';
import 'package:mizan/features/quick_input/domain/value_objects/speech_update.dart';

/// A [SpeechRecognizer] the test drives: [hear] and [fail] feed the current
/// listen.
class FakeSpeechRecognizer implements SpeechRecognizer {
  StreamController<Result<SpeechUpdate, QuickInputFailure>>? _current;
  var listens = 0;
  var stops = 0;

  bool get listening => _current != null;

  @override
  Stream<Result<SpeechUpdate, QuickInputFailure>> listen() {
    listens++;
    _current = StreamController<Result<SpeechUpdate, QuickInputFailure>>();
    return _current!.stream;
  }

  @override
  Future<void> stop() async => stops++;

  /// Text heard so far; [isFinal] ends the listen.
  void hear(String text, {bool isFinal = false}) {
    _current?.add(Ok(SpeechUpdate(text: text, isFinal: isFinal)));
    if (isFinal) _end();
  }

  void fail(QuickInputFailure failure) {
    _current?.add(Err(failure));
    _end();
  }

  void _end() {
    unawaited(_current?.close());
    _current = null;
  }
}
