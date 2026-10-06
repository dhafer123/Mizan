import 'package:dio/dio.dart';

import '../../domain/value_objects/group_invite.dart';
import '../../domain/value_objects/invite_preview.dart';

/// The server's `/groups/*` endpoints (server/groups/views.py). Give it the
/// signed-in [Dio]. Methods throw [DioException] for transport and HTTP
/// errors, and [FormatException] for an answer they can't read.
class GroupsApi {
  const GroupsApi(this._dio);

  final Dio _dio;

  Future<GroupInvite> createInvite(String groupId, {String? memberId}) async {
    final response = await _dio.post<Object?>(
      '/groups/$groupId/invites',
      data: {'memberId': ?memberId},
    );
    return switch (response.data) {
      {
        'token': final String token,
        'groupId': final String groupId,
        'expiresAt': final String expiresAt,
      } =>
        GroupInvite(
          token: token,
          groupId: groupId,
          memberId: (response.data! as Map)['memberId'] as String?,
          expiresAt: DateTime.parse(expiresAt),
        ),
      _ => throw const FormatException('Bad invite'),
    };
  }

  Future<InvitePreview> preview(String token) async {
    final response = await _dio.get<Object?>('/groups/invites/$token');
    return switch (response.data) {
      {
        'groupId': final String groupId,
        'groupName': final String groupName,
        'invitedBy': final String invitedBy,
        'expiresAt': final String expiresAt,
      } =>
        InvitePreview(
          groupId: groupId,
          groupName: groupName,
          memberName: (response.data! as Map)['memberName'] as String?,
          invitedBy: invitedBy,
          expiresAt: DateTime.parse(expiresAt),
        ),
      _ => throw const FormatException('Bad invite preview'),
    };
  }

  /// Returns the group's id.
  Future<String> join(String token) async {
    final response = await _dio.post<Object?>('/groups/invites/$token/join');
    return switch (response.data) {
      {'groupId': final String groupId} => groupId,
      _ => throw const FormatException('Bad join answer'),
    };
  }
}
