import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/budget_providers.dart';
import '../../../../app/di/core_providers.dart';
import '../../../../core/clock/year_month.dart';
import '../../../expenses/presentation/expense_list/month_expenses_provider.dart';
import '../../../expenses/presentation/shared/no_retry.dart';
import '../../../groups/presentation/shared/group_data_providers.dart';
import '../../domain/value_objects/run_out_forecast.dart';
import '../budget/budget_providers.dart';
import 'dashboard_provider.dart';

part 'forecast_provider.g.dart';

/// Whether the forecast counts what others owe me in groups as money I
/// have. Off by default: it may never be paid back. Kept for the session.
@Riverpod(keepAlive: true)
class IncludeOwedInForecast extends _$IncludeOwedInForecast {
  @override
  bool build() => false;

  void set(bool include) => state = include;
}

/// When money left runs out, from Home's money left and this and last
/// month's spending (always at least the 28 days the rates need).
///
/// Older spending isn't read, so someone with nothing in the last two
/// months is a cold start again: their recent rate would be 0 anyway.
@Riverpod(retry: noRetry)
Future<RunOutForecast> forecast(Ref ref) async {
  final today = ref.watch(clockProvider).now();
  final month = YearMonth.of(today);
  final dashboard = await ref.watch(dashboardProvider.future);
  final thisMonth = await ref.watch(monthExpensesProvider(month).future);
  final lastMonth = await ref.watch(
    monthExpensesProvider(month.previous).future,
  );
  final incomes = await ref.watch(incomeSourcesProvider.future);
  final groups = await ref.watch(myGroupMoneyProvider.future);
  final includeOwed = ref.watch(includeOwedInForecastProvider);

  return ref.watch(forecastRunOutProvider)(
    today: today,
    available: dashboard.available.available,
    incomes: incomes,
    expenses: [
      for (final day in [...thisMonth, ...lastMonth]) ...day.expenses,
    ],
    shares: groups.shares,
    owedToMe: includeOwed ? groups.owedToMe : null,
    monthlyBudget: dashboard.overview.totalLimit,
  );
}

/// Re-reads what the forecast combines, and the forecast.
void retryForecast(WidgetRef ref) {
  retryDashboard(ref);
  ref.invalidate(forecastProvider);
}
