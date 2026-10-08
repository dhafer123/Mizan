import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/budget_providers.dart';
import '../../../../app/di/core_providers.dart';
import '../../../../core/clock/year_month.dart';
import '../../../expenses/presentation/expense_list/month_expenses_provider.dart';
import '../../../expenses/presentation/shared/categories_provider.dart';
import '../../../expenses/presentation/shared/no_retry.dart';
import '../../../groups/presentation/shared/group_data_providers.dart';
import '../../domain/value_objects/budget_alert.dart';
import '../home/dashboard_provider.dart';
import '../home/forecast_provider.dart';

part 'alert_candidates_provider.g.dart';

/// Every budget alert that holds now, recomputed on every change to the
/// data Home shows. The forecast leaves out money owed to me.
///
/// Spending is this and last month's: the 4 weeks an unusual expense is
/// compared with can be a day or two short early in March.
@Riverpod(retry: noRetry)
Future<List<BudgetAlert>> alertCandidates(Ref ref) async {
  final today = ref.watch(clockProvider).now();
  final month = YearMonth.of(today);
  final dashboard = await ref.watch(dashboardProvider.future);
  final forecast = await ref.watch(forecastProvider(includeOwed: false).future);
  final categories = await ref.watch(categoriesProvider.future);
  final thisMonth = await ref.watch(monthExpensesProvider(month).future);
  final lastMonth = await ref.watch(
    monthExpensesProvider(month.previous).future,
  );
  final groups = await ref.watch(myGroupMoneyProvider.future);

  return ref.watch(computeBudgetAlertsProvider)(
    today: today,
    overview: dashboard.overview,
    forecast: forecast,
    next: dashboard.available.next,
    expenses: [
      for (final day in [...thisMonth, ...lastMonth]) ...day.expenses,
    ],
    shares: groups.shares,
    categories: categories,
  );
}
