import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/budget_providers.dart';
import '../../domain/value_objects/budget_alert.dart';
import 'alert_candidates_provider.dart';

/// Asks for notification permission once, then sends due budget alerts
/// whenever the data behind them changes, and checks again when the app
/// comes back (the day may have changed). Wraps the whole app; the
/// background sync checks while it's closed (ADR 0013).
class AlertsLifecycle extends ConsumerStatefulWidget {
  const AlertsLifecycle({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AlertsLifecycle> createState() => _AlertsLifecycleState();
}

class _AlertsLifecycleState extends ConsumerState<AlertsLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ref.read(requestAlertPermissionProvider)());
    ref.listenManual<AsyncValue<List<BudgetAlert>>>(alertCandidatesProvider, (
      _,
      next,
    ) {
      // A failure is shown where the data is (Home); alerts just wait
      // for the next change.
      if (next case AsyncData(:final value)) {
        unawaited(ref.read(sendBudgetAlertsProvider)(value));
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(alertCandidatesProvider);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
