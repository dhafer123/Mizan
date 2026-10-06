import 'package:dio/dio.dart';

import '../../../../app/db/app_database.dart';
import '../../../../core/clock/clock.dart';
import '../../../../core/result/result.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../domain/value_objects/outbox_counts.dart';
import '../../domain/value_objects/sync_error.dart';
import '../../domain/value_objects/sync_failure.dart';
import '../db/sync_local_store.dart';
import '../remote/sync_api.dart';

/// [SyncRepository] over the outbox, [SyncLocalStore] and [SyncApi].
class SyncRepositoryImpl implements SyncRepository {
  SyncRepositoryImpl({
    required AppDatabase db,
    required SyncApi api,
    required Clock clock,
    required Future<String> Function() deviceId,
    required Future<bool> Function() signedIn,
  }) : _db = db,
       _store = SyncLocalStore(db),
       _api = api,
       _clock = clock,
       _deviceId = deviceId,
       _signedIn = signedIn;

  final AppDatabase _db;
  final SyncLocalStore _store;
  final SyncApi _api;
  final Clock _clock;
  final Future<String> Function() _deviceId;
  final Future<bool> Function() _signedIn;

  /// Stops a push that keeps finding new ops (e.g. a write loop).
  static const maxPushRounds = 50;

  static const _accepted = {'applied', 'merged'};

  @override
  Future<Result<({int accepted, int rejected}), SyncFailure>> push() async {
    var accepted = 0, rejected = 0;
    try {
      await _db.outboxDao.resetSending();
      final deviceId = await _deviceId();
      for (var round = 0; round < maxPushRounds; round++) {
        final ops = await _db.outboxDao.pending(limit: SyncApi.maxOps);
        if (ops.isEmpty) break;
        final seqs = [for (final op in ops) op.seq];
        await _db.outboxDao.markSending(seqs);

        final List<PushResult> results;
        try {
          results = await _api.push(deviceId, ops);
        } on Object {
          await _db.outboxDao.markRetry(seqs);
          rethrow;
        }

        final done = <int>[];
        final refused = <int, String>{};
        for (final (i, result) in results.indexed) {
          if (_accepted.contains(result.status)) {
            done.add(ops[i].seq);
          } else {
            refused[ops[i].seq] = result.reason ?? result.status;
          }
        }
        await _db.transaction(() async {
          await _db.outboxDao.removeAcknowledged(done);
          await _db.outboxDao.markRejected(refused);
          // These ops left the queue: rebuild their rows from the server's.
          for (final (i, result) in results.indexed) {
            await _store.applyPushResult(
              ops[i].entity,
              ops[i].entityId,
              result.state,
            );
          }
        });
        accepted += done.length;
        rejected += refused.length;
      }
      return Ok((accepted: accepted, rejected: rejected));
    } on DioException catch (e) {
      return Err(await _fromDio(e));
    } on FormatException {
      return const Err(SyncFailure(SyncError.server));
    } on Object {
      return const Err(SyncFailure(SyncError.storage));
    }
  }

  @override
  Future<Result<int, SyncFailure>> pull({required String accountId}) async {
    var applied = 0;
    try {
      var cursor = (await _db.syncStateDao.read()).cursor;
      while (true) {
        final page = await _api.pull(since: cursor);
        applied += await _store.applyPage(
          page,
          accountId: accountId,
          now: _clock.now(),
        );
        cursor = page.cursor;
        if (!page.hasMore) break;
      }
      // Groups this account just joined: their older rows.
      for (final backfill in await _store.pendingBackfills()) {
        var since = backfill.cursor;
        while (true) {
          final page = await _api.pull(since: since, groupId: backfill.groupId);
          await _store.applyBackfillPage(
            backfill.groupId,
            page,
            accountId: accountId,
          );
          applied += page.changes.length;
          since = page.cursor;
          if (!page.hasMore) break;
        }
      }
      return Ok(applied);
    } on DioException catch (e) {
      return Err(await _fromDio(e));
    } on AccountChangedException {
      return const Err(SyncFailure(SyncError.accountChanged));
    } on FormatException {
      return const Err(SyncFailure(SyncError.server));
    } on TypeError {
      // A pulled row that doesn't fit the local table (e.g. a missing key).
      return const Err(SyncFailure(SyncError.server));
    } on Object {
      return const Err(SyncFailure(SyncError.storage));
    }
  }

  @override
  Future<Result<bool, SyncFailure>> claimFor(String accountId) async {
    try {
      return Ok(await _store.claimFor(accountId));
    } on Object {
      return const Err(SyncFailure(SyncError.storage));
    }
  }

  @override
  Stream<OutboxCounts> watchOutbox() => _db.outboxDao.watchCounts().map(
    (c) => OutboxCounts(pending: c.pending, rejected: c.rejected),
  );

  @override
  Future<DateTime?> lastSyncAt() async =>
      (await _db.syncStateDao.read()).lastSyncAt;

  Future<SyncFailure> _fromDio(DioException e) async {
    switch (e.type) {
      case DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.connectionError:
        return const SyncFailure(SyncError.offline);
      case DioExceptionType.badResponse when e.response?.statusCode == 401:
        // The interceptor already tried a refresh. If that ended the
        // session, we're signed out; if it couldn't reach the server, the
        // session is kept and this is just being offline.
        return SyncFailure(
          await _signedIn() ? SyncError.offline : SyncError.sessionExpired,
        );
      case _:
        return const SyncFailure(SyncError.server);
    }
  }
}
