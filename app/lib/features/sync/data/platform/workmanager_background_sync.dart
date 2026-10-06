import 'package:workmanager/workmanager.dart' as wm;

import '../../domain/repositories/background_sync.dart';

/// [BackgroundSync] with Android WorkManager: a periodic task, only when a
/// network is connected. The task itself is `backgroundSyncDispatcher`.
class WorkmanagerBackgroundSync implements BackgroundSync {
  const WorkmanagerBackgroundSync(this._workmanager);

  final wm.Workmanager _workmanager;

  static const uniqueName = 'mizan.sync.periodic';
  static const taskName = 'mizan.sync';

  /// WorkManager's minimum period.
  static const frequency = Duration(minutes: 15);

  @override
  Future<void> enable() async {
    try {
      await _workmanager.registerPeriodicTask(
        uniqueName,
        taskName,
        frequency: frequency,
        constraints: wm.Constraints(networkType: wm.NetworkType.connected),
        existingWorkPolicy: wm.ExistingPeriodicWorkPolicy.keep,
      );
    } on Object {
      // Best effort: foreground sync still works without it.
    }
  }

  @override
  Future<void> disable() async {
    try {
      await _workmanager.cancelByUniqueName(uniqueName);
    } on Object {
      // Nothing scheduled, or no plugin (tests).
    }
  }
}
