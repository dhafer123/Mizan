import 'package:freezed_annotation/freezed_annotation.dart';

part 'speech_update.freezed.dart';

/// What the recognizer has heard so far.
@freezed
abstract class SpeechUpdate with _$SpeechUpdate {
  const factory SpeechUpdate({
    required String text,

    /// The last update of a listen: the speaker paused or it was stopped.
    @Default(false) bool isFinal,
  }) = _SpeechUpdate;
}
