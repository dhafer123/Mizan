import 'package:freezed_annotation/freezed_annotation.dart';

part 'push_message.freezed.dart';

/// A push from the server (server/notifications). Every one means "data
/// changed on the server"; some also carry a notification to show.
@freezed
abstract class PushMessage with _$PushMessage {
  const factory PushMessage({
    /// The group it is about, if any (opening the notification goes there).
    String? groupId,

    /// Set when there is a notification to show.
    String? title,
    String? body,
  }) = _PushMessage;
}
