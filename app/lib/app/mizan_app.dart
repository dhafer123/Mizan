import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/beta/presentation/usage_report_lifecycle.dart';
import '../features/budget/presentation/alerts/alerts_lifecycle.dart';
import '../features/settings/domain/value_objects/theme_choice.dart';
import '../features/settings/presentation/appearance/reduce_motion_controller.dart';
import '../features/settings/presentation/appearance/theme_choice_controller.dart';
import '../features/settings/presentation/lock/app_lock_gate.dart';
import '../features/sync/presentation/sync_lifecycle.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root widget. Expects a [ProviderScope] above it.
class MizanApp extends ConsumerWidget {
  const MizanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reduced motion if the phone asks, or the app's own switch is on.
    final phoneStill = MediaQuery.disableAnimationsOf(context);
    final still =
        phoneStill ||
        (ref.watch(reduceMotionControllerProvider).value ?? false);
    ThemeData calm(ThemeData theme) => still
        ? theme.copyWith(pageTransitionsTheme: const _NoPageTransitions())
        : theme;

    return MaterialApp.router(
      title: 'Mizan',
      debugShowCheckedModeBanner: false,
      theme: calm(AppTheme.light()),
      darkTheme: calm(AppTheme.dark()),
      themeAnimationDuration: still ? Duration.zero : kThemeAnimationDuration,
      // `main` loads the choice before the first frame, so there's no flash.
      themeMode:
          (ref.watch(themeChoiceControllerProvider).value ?? ThemeChoice.system)
              .themeMode,
      routerConfig: ref.watch(appRouterProvider),
      // Above the navigator, so the lock covers every screen and sheet.
      builder: (context, child) {
        final app = SyncLifecycle(
          child: AlertsLifecycle(
            child: UsageReportLifecycle(child: AppLockGate(child: child!)),
          ),
        );
        // Every animated widget reads `disableAnimations`, so this one
        // switch holds the whole app still.
        return still && !phoneStill
            ? MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: app,
              )
            : app;
      },
    );
  }
}

/// Screens appear at once, without sliding or zooming in.
class _NoPageTransitions extends PageTransitionsTheme {
  const _NoPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
