import 'package:freezed_annotation/freezed_annotation.dart';

import 'invite_link.dart';

part 'group_invite.freezed.dart';

/// An invite made on the server: works once, until [expiresAt].
@freezed
abstract class GroupInvite with _$GroupInvite {
  const GroupInvite._();

  const factory GroupInvite({
    required String token,
    required String groupId,

    /// The placeholder whoever joins becomes, or null to add a new member.
    String? memberId,
    required DateTime expiresAt,
  }) = _GroupInvite;

  /// What to share, as text or a QR code.
  String get link => InviteLink.forToken(token);
}
