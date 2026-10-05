import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/budget_providers.dart';
import '../../../../app/di/core_providers.dart';
import '../../../../core/clock/year_month.dart';
import '../../../expenses/presentation/expense_list/month_expenses_provider.dart';
import '../../../expenses/presentation/shared/categories_provider.dart';
import '../../../expenses/presentation/shared/no_retry.dart';
import '../../domain/value_objects/dashboard.dart';
import '../budget/budget_providers.dart';

part 'dashboard_provider.g.dart';

/// The home screen for the current month, recomputed whenever a category,
/// expense, budget or income source changes.
///
/// Last month's expenses are read too, so "recent" isn't empty on the 1st.
@Riverpod(retry: noRetry)
Future<Dashboard> dashboard(Ref ref) async {
  final today = ref.watch(clockProvider).now();
  final month = YearMonth.of(today);
  final categories = await ref.watch(categoriesProvider.future);
  final thisMonth = await ref.watch(monthExpensesProvider(month).future);
  final lastMonth = await ref.watch(
    monthExpensesProvider(month.previous).future,
  );
  final budgets = await ref.watch(budgetsProvider.future);
  final incomes = await ref.watch(incomeSourcesProvider.future);

  return ref.watch(computeDashboardProvider)(
    today: today,
    currency: ref.watch(appCurrencyProvider),
    budgets: budgets,
    categories: categories,
    incomes: incomes,
    expenses: [
      for (final day in [...thisMonth, ...lastMonth]) ...day.expenses,
    ],
  );
}

/// Re-reads everything [dashboardProvider] combines: a failure is held by
/// the source that failed.
void retryDashboard(WidgetRef ref) {
  final month = YearMonth.of(ref.read(clockProvider).now());
  ref
    ..invalidate(categoriesProvider)
    ..invalidate(monthExpensesProvider(month))
    ..invalidate(monthExpensesProvider(month.previous))
    ..invalidate(budgetsProvider)
    ..invalidate(incomeSourcesProvider)
    ..invalidate(dashboardProvider);
}
