import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/budget/presentation/alerts/alerts_lifecycle.dart';
import '../features/settings/presentation/lock/app_lock_gate.dart';
import '../features/sync/presentation/sync_lifecycle.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root widget. Expects a [ProviderScope] above it.
class MizanApp extends ConsumerWidget {
  const MizanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Mizan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: ref.watch(appRouterProvider),
      // Above the navigator, so the lock covers every screen and sheet.
      builder: (context, child) => SyncLifecycle(
        child: AlertsLifecycle(child: AppLockGate(child: child!)),
      ),
    );
  }
}
