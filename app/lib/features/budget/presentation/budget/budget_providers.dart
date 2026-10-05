import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/budget_providers.dart';
import '../../../../app/di/core_providers.dart';
import '../../../../core/clock/year_month.dart';
import '../../../../core/result/result.dart';
import '../../../expenses/presentation/expense_list/month_expenses_provider.dart';
import '../../../expenses/presentation/shared/categories_provider.dart';
import '../../../expenses/presentation/shared/no_retry.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/income_source.dart';
import 'budget_screen_data.dart';

part 'budget_providers.g.dart';

/// The income sources, by name. A failure becomes the error state.
@Riverpod(retry: noRetry)
Stream<List<IncomeSource>> incomeSources(Ref ref) => ref
    .watch(watchIncomeSourcesProvider)()
    .map(
      (result) => switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      },
    );

/// Every month budget ever set. A failure becomes the error state.
@Riverpod(retry: noRetry)
Stream<List<Budget>> budgets(Ref ref) => ref
    .watch(watchBudgetsProvider)()
    .map(
      (result) => switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      },
    );

/// Everything the budget screen shows for [month], recomputed whenever a
/// category, expense, budget or income source changes.
@Riverpod(retry: noRetry)
Future<BudgetScreenData> budgetScreen(Ref ref, YearMonth month) async {
  final currency = ref.watch(appCurrencyProvider);
  final today = ref.watch(clockProvider).now();
  final categories = await ref.watch(categoriesProvider.future);
  final days = await ref.watch(monthExpensesProvider(month).future);
  final budgets = await ref.watch(budgetsProvider.future);
  final incomes = await ref.watch(incomeSourcesProvider.future);
  final expenses = [for (final day in days) ...day.expenses];

  return BudgetScreenData(
    overview: ref.watch(computeBudgetOverviewProvider)(
      month: month,
      currency: currency,
      budgets: budgets,
      categories: categories,
      expenses: expenses,
    ),
    available: ref.watch(computeMoneyAvailableProvider)(
      month: month,
      currency: currency,
      incomes: incomes,
      expenses: expenses,
      today: today,
    ),
    hasIncome: incomes.isNotEmpty,
    isCurrentMonth: month == YearMonth.of(today),
  );
}

/// Re-reads everything [budgetScreenProvider] combines: a failure is held by
/// the source that failed, so re-running the combination alone would show
/// the same error again.
void retryBudgetScreen(WidgetRef ref, YearMonth month) => ref
  ..invalidate(categoriesProvider)
  ..invalidate(monthExpensesProvider(month))
  ..invalidate(budgetsProvider)
  ..invalidate(incomeSourcesProvider)
  ..invalidate(budgetScreenProvider(month));
