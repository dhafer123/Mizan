import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_controller.dart';
import 'lock_screen.dart';

/// Wraps the whole app (`MaterialApp.builder`): tells [AppLock] when the app
/// goes to the background and comes back, and covers the app while locked.
///
/// The app stays mounted underneath, so unlocking returns to where the user
/// was, but it is hidden and gets no input while locked.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final lock = ref.read(appLockProvider.notifier);
        switch (state) {
          case AppLifecycleState.hidden || AppLifecycleState.paused:
            lock.backgrounded();
          case AppLifecycleState.resumed:
            lock.resumed();
          case AppLifecycleState.inactive || AppLifecycleState.detached:
            // Inactive includes the biometric prompt itself: not "away".
            break;
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appLockProvider, (previous, next) {
      // Close the keyboard of whatever field was in use.
      if (next == AppLockState.locked) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
    final state = ref.watch(appLockProvider);
    final open = state == AppLockState.unlocked;

    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: !open,
          child: TickerMode(enabled: open, child: widget.child),
        ),
        if (state == AppLockState.locked) const LockScreen(),
        if (state == AppLockState.checking)
          ColoredBox(color: Theme.of(context).colorScheme.surface),
      ],
    );
  }
}
