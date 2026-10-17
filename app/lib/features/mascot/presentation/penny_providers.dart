import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/di/mascot_providers.dart';
import '../../budget/presentation/alerts/alert_candidates_provider.dart';
import '../../budget/presentation/home/dashboard_provider.dart';
import '../../budget/presentation/home/forecast_provider.dart';
import '../../expenses/presentation/shared/no_retry.dart';
import '../../sync/domain/value_objects/sync_phase.dart';
import '../../sync/presentation/sync_status_provider.dart';
import '../domain/value_objects/penny_state.dart';
import 'penny_lines.dart';

part 'penny_providers.g.dart';

/// Penny's mood on Home, recomputed whenever the data Home shows changes,
/// or sync goes offline. Same facts as the budget alerts (without money
/// owed to me, like them).
@Riverpod(retry: noRetry)
Future<PennyState> pennyHome(Ref ref) async {
  final dashboard = await ref.watch(dashboardProvider.future);
  final forecast = await ref.watch(forecastProvider(includeOwed: false).future);
  final alerts = await ref.watch(alertCandidatesProvider.future);
  // Unknown sync status (still loading, or failed) isn't "offline".
  final phase = ref.watch(syncStatusProvider).value?.phase;

  return ref.watch(readPennyProvider)(
    alerts: alerts,
    forecast: forecast,
    next: dashboard.available.next,
    hasIncome: !dashboard.available.income.isZero,
    spentThisMonth: !dashboard.isEmptyMonth,
    offline: phase == SyncPhase.offline,
  );
}

/// What Penny is reacting to right now, if anything: she shows it for
/// [hold], then goes back to her Home mood.
@Riverpod(keepAlive: true)
class PennyReaction extends _$PennyReaction {
  static const hold = Duration(seconds: 5);

  Timer? _timer;

  @override
  PennyMoment? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void react(PennyMoment moment) {
    _timer?.cancel();
    state = moment;
    _timer = Timer(hold, () => state = null);
  }
}
