import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/sync/data/platform/connectivity_plus_monitor.dart';
import '../../features/sync/data/platform/firebase_push_messaging.dart';
import '../../features/sync/data/platform/workmanager_background_sync.dart';
import '../../features/sync/data/remote/push_token_api.dart';
import '../../features/sync/data/remote/sync_api.dart';
import '../../features/sync/data/repositories/push_token_repository_impl.dart';
import '../../features/sync/data/repositories/sync_repository_impl.dart';
import '../../features/sync/domain/repositories/background_sync.dart';
import '../../features/sync/domain/repositories/connectivity_monitor.dart';
import '../../features/sync/domain/repositories/push_messaging.dart';
import '../../features/sync/domain/repositories/push_token_repository.dart';
import '../../features/sync/domain/repositories/sync_repository.dart';
import '../../features/sync/domain/usecases/claim_local_data.dart';
import '../../features/sync/domain/usecases/get_last_sync_time.dart';
import '../../features/sync/domain/usecases/push_listener.dart';
import '../../features/sync/domain/usecases/sync_now.dart';
import '../../features/sync/domain/usecases/sync_scheduler.dart';
import '../../features/sync/domain/usecases/watch_outbox_counts.dart';
import 'auth_providers.dart';
import 'core_providers.dart';
import 'database_providers.dart';

part 'sync_providers.g.dart';

@Riverpod(keepAlive: true)
SyncApi syncApi(Ref ref) => SyncApi(ref.watch(apiDioProvider));

@Riverpod(keepAlive: true)
SyncRepository syncRepository(Ref ref) {
  final sessions = ref.watch(sessionStoreProvider);
  return SyncRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    api: ref.watch(syncApiProvider),
    clock: ref.watch(clockProvider),
    deviceId: sessions.deviceId,
    signedIn: () async => await sessions.read() != null,
  );
}

/// Override with a fake in tests.
@Riverpod(keepAlive: true)
ConnectivityMonitor connectivityMonitor(Ref ref) =>
    ConnectivityPlusMonitor(Connectivity());

/// Override with a fake in tests.
@Riverpod(keepAlive: true)
BackgroundSync backgroundSync(Ref ref) =>
    WorkmanagerBackgroundSync(Workmanager());

@Riverpod(keepAlive: true)
SyncNow syncNow(Ref ref) =>
    SyncNow(ref.watch(syncRepositoryProvider), ref.watch(clockProvider));

@Riverpod(keepAlive: true)
ClaimLocalData claimLocalData(Ref ref) =>
    ClaimLocalData(ref.watch(syncRepositoryProvider));

@Riverpod(keepAlive: true)
WatchOutboxCounts watchOutboxCounts(Ref ref) =>
    WatchOutboxCounts(ref.watch(syncRepositoryProvider));

@Riverpod(keepAlive: true)
GetLastSyncTime getLastSyncTime(Ref ref) =>
    GetLastSyncTime(ref.watch(syncRepositoryProvider));

/// The app's sync loop. Started by `SyncLifecycle` when the app starts.
@Riverpod(keepAlive: true)
SyncScheduler syncScheduler(Ref ref) {
  final scheduler = SyncScheduler(
    syncNow: ref.watch(syncNowProvider),
    claim: ref.watch(claimLocalDataProvider),
    lastSyncAt: ref.watch(getLastSyncTimeProvider).call,
    accounts: ref.watch(watchAccountProvider)().map((a) => a?.id),
    online: ref.watch(connectivityMonitorProvider).watchOnline(),
    outbox: ref.watch(watchOutboxCountsProvider)(),
    background: ref.watch(backgroundSyncProvider),
  )..start();
  ref.onDispose(scheduler.dispose);
  return scheduler;
}

/// Override with a fake in tests.
@Riverpod(keepAlive: true)
PushMessaging pushMessaging(Ref ref) =>
    FirebasePushMessaging(ref.watch(localNotificationsProvider));

@Riverpod(keepAlive: true)
PushTokenRepository pushTokenRepository(Ref ref) => PushTokenRepositoryImpl(
  PushTokenApi(ref.watch(apiDioProvider)),
  deviceId: ref.watch(sessionStoreProvider).deviceId,
);

/// Pushes trigger a sync. Started by `SyncLifecycle` with the app.
@Riverpod(keepAlive: true)
PushListener pushListener(Ref ref) {
  final scheduler = ref.watch(syncSchedulerProvider);
  final listener = PushListener(
    push: ref.watch(pushMessagingProvider),
    tokens: ref.watch(pushTokenRepositoryProvider),
    accounts: ref.watch(watchAccountProvider)().map((a) => a?.id),
    onDataChanged: scheduler.syncNow,
  );
  unawaited(listener.start());
  ref.onDispose(listener.dispose);
  return listener;
}
