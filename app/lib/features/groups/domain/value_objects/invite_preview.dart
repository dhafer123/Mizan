import 'package:freezed_annotation/freezed_annotation.dart';

part 'invite_preview.freezed.dart';

/// What an invite leads to, shown before joining.
@freezed
abstract class InvitePreview with _$InvitePreview {
  const factory InvitePreview({
    required String groupId,
    required String groupName,

    /// The placeholder the joiner becomes, or null for a new member.
    String? memberName,
    required String invitedBy,
    required DateTime expiresAt,
  }) = _InvitePreview;
}
