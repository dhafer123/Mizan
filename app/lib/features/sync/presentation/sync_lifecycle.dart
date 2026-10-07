import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/sync_providers.dart';
import '../../../app/router/app_router.dart';

/// Starts the sync scheduler and push with the app, syncs when the app
/// comes back to the foreground, and opens the group of a tapped
/// notification. Wraps the whole app.
class SyncLifecycle extends ConsumerStatefulWidget {
  const SyncLifecycle({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncLifecycle> createState() => _SyncLifecycleState();
}

class _SyncLifecycleState extends ConsumerState<SyncLifecycle>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _opened;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(syncSchedulerProvider); // Builds and starts it.
    _opened = ref
        .read(pushListenerProvider)
        .openedGroups
        .listen((id) => ref.read(appRouterProvider).push(AppRoutes.group(id)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_opened?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncSchedulerProvider).syncNow();
      unawaited(ref.read(pushListenerProvider).retry());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
