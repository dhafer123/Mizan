import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../core/result/result.dart';
import '../../domain/repositories/speech_recognizer.dart';
import '../../domain/value_objects/quick_input_error.dart';
import '../../domain/value_objects/quick_input_failure.dart';
import '../../domain/value_objects/speech_update.dart';

/// [SpeechRecognizer] on the phone's own recognizer (speech_to_text 7.4),
/// in the phone's language. Offline when its language pack is installed.
///
/// The plugin is a singleton and keeps the callbacks of its first
/// `initialize`, so they route to whichever listen is current.
class SpeechToTextRecognizer implements SpeechRecognizer {
  SpeechToTextRecognizer([SpeechToText? speech])
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  StreamController<Result<SpeechUpdate, QuickInputFailure>>? _current;
  var _heard = '';

  /// How long a pause ends the phrase, and the longest a phrase can be.
  static const _pauseFor = Duration(seconds: 3);
  static const _listenFor = Duration(seconds: 30);

  @override
  Stream<Result<SpeechUpdate, QuickInputFailure>> listen() {
    _finish();
    final controller =
        StreamController<Result<SpeechUpdate, QuickInputFailure>>();
    _current = controller;
    _heard = '';
    unawaited(_start(controller));
    return controller.stream;
  }

  Future<void> _start(
    StreamController<Result<SpeechUpdate, QuickInputFailure>> controller,
  ) async {
    try {
      final ready = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
        options: [SpeechToText.androidNoBluetooth],
      );
      if (!identical(controller, _current)) return;
      if (!ready) {
        _fail(QuickInputError.micUnavailable);
        return;
      }
      await _speech.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          pauseFor: _pauseFor,
          listenFor: _listenFor,
        ),
      );
    } on Object {
      if (identical(controller, _current)) {
        _fail(QuickInputError.micUnavailable);
      }
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } on Object {
      _finish();
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    final controller = _current;
    if (controller == null) return;
    _heard = result.recognizedWords;
    if (!result.finalResult) {
      controller.add(Ok(SpeechUpdate(text: _heard)));
      return;
    }
    _finish();
  }

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus || status == 'doneNoResult') {
      _finish();
    }
  }

  void _onError(SpeechRecognitionError error) {
    final message = error.errorMsg;
    _fail(switch (message) {
      'error_no_match' ||
      'error_speech_timeout' => QuickInputError.nothingHeard,
      'error_permission' ||
      'error_insufficient_permissions' => QuickInputError.micUnavailable,
      _ => QuickInputError.speechFailed,
    });
  }

  /// Sends what was heard as final (or "nothing heard") and ends the
  /// current listen.
  void _finish() {
    final controller = _current;
    if (controller == null) return;
    _current = null;
    controller.add(
      _heard.trim().isEmpty
          ? const Err(QuickInputFailure(QuickInputError.nothingHeard))
          : Ok(SpeechUpdate(text: _heard, isFinal: true)),
    );
    unawaited(controller.close());
  }

  void _fail(QuickInputError error) {
    final controller = _current;
    if (controller == null) return;
    _current = null;
    controller.add(Err(QuickInputFailure(error)));
    unawaited(controller.close());
  }
}
