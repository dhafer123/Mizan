import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/sync_providers.dart';

/// Starts the sync scheduler with the app, and syncs when the app comes
/// back to the foreground. Wraps the whole app.
class SyncLifecycle extends ConsumerStatefulWidget {
  const SyncLifecycle({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncLifecycle> createState() => _SyncLifecycleState();
}

class _SyncLifecycleState extends ConsumerState<SyncLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(syncSchedulerProvider); // Builds and starts it.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncSchedulerProvider).syncNow();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
