import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../app/db/app_database.dart';

/// One op's outcome from `/sync/push`, with the server's current row when
/// the user may see it.
typedef PushResult = ({
  String status,
  String? reason,
  Map<String, Object?>? state,
});

/// One row from `/sync/pull`: the server's state of an entity (or a
/// history entry), in the app's sync JSON.
typedef PulledChange = ({
  String entity,
  int serverSeq,
  Map<String, Object?> state,
});

typedef PullPage = ({List<PulledChange> changes, int cursor, bool hasMore});

/// The server's `/sync/*` endpoints (server/sync/push.py, pull.py). Give it
/// the signed-in [Dio] (with the `AuthInterceptor`). Methods throw
/// [DioException] for transport and HTTP errors, and [FormatException] for
/// an answer they can't read.
class SyncApi {
  const SyncApi(this._dio);

  final Dio _dio;

  static const pushPath = '/sync/push';
  static const pullPath = '/sync/pull';

  /// At most this many ops per push (the server's limit).
  static const maxOps = 200;

  /// One result per op, in order.
  Future<List<PushResult>> push(String deviceId, List<OutboxEntry> ops) async {
    final response = await _dio.post<Object?>(
      pushPath,
      data: {
        'deviceId': deviceId,
        'ops': [
          for (final op in ops)
            {
              'opId': op.opId,
              'entity': op.entity,
              'entityId': op.entityId,
              'opType': op.opType.name,
              'baseVersion': op.baseVersion,
              'changedFields': jsonDecode(op.changedFields),
            },
        ],
      },
    );
    final results = switch (response.data) {
      {'results': final List<Object?> results} => results,
      _ => throw const FormatException('No results'),
    };
    if (results.length != ops.length) {
      throw const FormatException('One result per op expected');
    }
    return [
      for (final result in results)
        switch (result) {
          {'status': final String status} => (
            status: status,
            reason: result['reason'] as String?,
            state: switch (result['state']) {
              final Map<String, Object?> state => state,
              _ => null,
            },
          ),
          _ => throw const FormatException('Bad result'),
        },
    ];
  }

  /// Changes since [since]. With [groupId], only that group's rows: the
  /// backfill after joining it.
  Future<PullPage> pull({
    required int since,
    int limit = maxOps,
    String? groupId,
  }) async {
    final response = await _dio.get<Object?>(
      pullPath,
      queryParameters: {'since': since, 'limit': limit, 'group': ?groupId},
    );
    return switch (response.data) {
      {
        'changes': final List<Object?> changes,
        'cursor': final int cursor,
        'hasMore': final bool hasMore,
      } =>
        (
          changes: [for (final change in changes) _change(change)],
          cursor: cursor,
          hasMore: hasMore,
        ),
      _ => throw const FormatException('Bad pull page'),
    };
  }

  static PulledChange _change(Object? json) => switch (json) {
    {
      'entity': final String entity,
      'serverSeq': final int serverSeq,
      'state': final Map<String, Object?> state,
    } =>
      (entity: entity, serverSeq: serverSeq, state: state),
    _ => throw const FormatException('Bad change'),
  };
}
