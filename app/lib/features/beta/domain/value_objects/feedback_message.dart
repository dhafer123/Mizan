import 'package:freezed_annotation/freezed_annotation.dart';

part 'feedback_message.freezed.dart';

/// What the feedback button sends: anonymous, unless [contact] is given.
@freezed
abstract class FeedbackMessage with _$FeedbackMessage {
  const factory FeedbackMessage({
    required String message,

    /// An email or phone number to get a reply; empty for none.
    @Default('') String contact,
    required String appVersion,
  }) = _FeedbackMessage;

  /// Same limits as the server (server/beta/serializers.py).
  static const maxLength = 2000;
  static const maxContactLength = 254;
}
