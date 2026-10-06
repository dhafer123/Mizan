import 'package:freezed_annotation/freezed_annotation.dart';

part 'member.freezed.dart';

/// Someone in a group. A placeholder ([userId] null) stands for someone
/// without the app yet: expenses can name them, and they keep that history
/// when they join with an invite made for them.
@freezed
abstract class Member with _$Member {
  const Member._();

  const factory Member({
    required String id,
    required String groupId,

    /// The account behind this member, or null for a placeholder.
    String? userId,
    required String displayName,
  }) = _Member;

  bool get isPlaceholder => userId == null;
}
