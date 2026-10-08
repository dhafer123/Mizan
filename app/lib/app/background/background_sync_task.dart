import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/result/result.dart';
import '../../features/budget/presentation/alerts/alert_candidates_provider.dart';
import '../../features/sync/domain/value_objects/sync_error.dart';
import '../di/auth_providers.dart';
import '../di/budget_providers.dart';
import '../di/sync_providers.dart';

/// WorkManager's entry point: a separate isolate that Android starts about
/// every 15 minutes while an account is signed in, even with the app
/// closed. It builds the same providers as the app, syncs once, then
/// sends any budget alerts that are due (ADR 0013).
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final container = ProviderContainer();
    try {
      final synced = await runBackgroundSync(container);
      await runBackgroundAlerts(container);
      return synced;
    } on Object {
      return false; // WorkManager retries later.
    } finally {
      container.dispose();
    }
  });
}

/// One sync with [container]'s providers. True when there is nothing left
/// to do (synced, or signed out); false asks WorkManager to retry.
Future<bool> runBackgroundSync(ProviderContainer container) async {
  final session = await container.read(sessionStoreProvider).read(fresh: true);
  if (session == null) return true;
  final account = session.account.id;

  final claimed = await container.read(claimLocalDataProvider)(account);
  if (claimed.isErr) return false;
  final result = await container.read(syncNowProvider)(accountId: account);
  return switch (result) {
    Ok() => true,
    Err(:final failure) => switch (failure.error) {
      SyncError.sessionExpired || SyncError.accountChanged => true,
      SyncError.offline || SyncError.server || SyncError.storage => false,
    },
  };
}

/// Sends the budget alerts due now with [container]'s providers. Failures
/// are dropped: the next run, or the app, checks again.
Future<void> runBackgroundAlerts(ProviderContainer container) async {
  // Keeps the provider (and the streams it reads) alive while awaited.
  final keep = container.listen(alertCandidatesProvider, (_, _) {});
  try {
    final candidates = await container.read(alertCandidatesProvider.future);
    await container.read(sendBudgetAlertsProvider)(candidates);
  } on Object {
    // Nothing to do until the next check.
  } finally {
    keep.close();
  }
}
