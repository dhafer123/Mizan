import 'dart:async';

import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/sync/domain/repositories/background_sync.dart';
import 'package:mizan/features/sync/domain/repositories/connectivity_monitor.dart';
import 'package:mizan/features/sync/domain/repositories/sync_repository.dart';
import 'package:mizan/features/sync/domain/value_objects/outbox_counts.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_failure.dart';

/// A scriptable [SyncRepository]. Push and pull succeed unless a failure is
/// queued; set [gate] to hold a push open.
class FakeSyncRepository implements SyncRepository {
  final calls = <String>[];
  final claims = <String>[];

  /// Failures for the next pushes, in order (null = succeed).
  final pushFailures = <SyncFailure?>[];
  final pullFailures = <SyncFailure?>[];

  SyncFailure? claimFailure;
  var claimWipes = false;
  DateTime? storedLastSync;
  Completer<void>? gate;

  final outbox = StreamController<OutboxCounts>.broadcast();

  int get syncs => calls.where((c) => c == 'push').length;

  Future<void> close() => outbox.close();

  @override
  Future<Result<({int accepted, int rejected}), SyncFailure>> push() async {
    calls.add('push');
    await gate?.future;
    final failure = pushFailures.isEmpty ? null : pushFailures.removeAt(0);
    return failure == null
        ? const Ok((accepted: 1, rejected: 0))
        : Err(failure);
  }

  @override
  Future<Result<int, SyncFailure>> pull({required String accountId}) async {
    calls.add('pull:$accountId');
    final failure = pullFailures.isEmpty ? null : pullFailures.removeAt(0);
    return failure == null ? const Ok(2) : Err(failure);
  }

  @override
  Future<Result<bool, SyncFailure>> claimFor(String accountId) async {
    claims.add(accountId);
    return switch (claimFailure) {
      final f? => Err(f),
      null => Ok(claimWipes),
    };
  }

  @override
  Stream<OutboxCounts> watchOutbox() => outbox.stream;

  @override
  Future<DateTime?> lastSyncAt() async => storedLastSync;
}

class FakeConnectivity implements ConnectivityMonitor {
  FakeConnectivity({bool online = true}) : _online = online;

  bool _online;
  final _changes = StreamController<bool>.broadcast();

  Future<void> close() => _changes.close();

  set online(bool value) {
    _online = value;
    _changes.add(value);
  }

  @override
  Stream<bool> watchOnline() async* {
    yield _online;
    yield* _changes.stream;
  }
}

class FakeBackgroundSync implements BackgroundSync {
  var enabled = false;
  final calls = <String>[];

  @override
  Future<void> enable() async {
    enabled = true;
    calls.add('enable');
  }

  @override
  Future<void> disable() async {
    enabled = false;
    calls.add('disable');
  }
}
