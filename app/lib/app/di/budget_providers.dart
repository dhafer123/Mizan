import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/budget/data/repositories/budget_repository_impl.dart';
import '../../features/budget/data/repositories/income_source_repository_impl.dart';
import '../../features/budget/domain/repositories/budget_repository.dart';
import '../../features/budget/domain/repositories/income_source_repository.dart';
import '../../features/budget/domain/usecases/add_income_source.dart';
import '../../features/budget/domain/usecases/compute_budget_overview.dart';
import '../../features/budget/domain/usecases/compute_money_available.dart';
import '../../features/budget/domain/usecases/delete_income_source.dart';
import '../../features/budget/domain/usecases/edit_income_source.dart';
import '../../features/budget/domain/usecases/set_monthly_budget.dart';
import '../../features/budget/domain/usecases/validate_income_source.dart';
import '../../features/budget/domain/usecases/watch_budgets.dart';
import '../../features/budget/domain/usecases/watch_income_sources.dart';
import 'core_providers.dart';
import 'database_providers.dart';

part 'budget_providers.g.dart';

@Riverpod(keepAlive: true)
IncomeSourceRepository incomeSourceRepository(Ref ref) =>
    IncomeSourceRepositoryImpl(ref.watch(appDatabaseProvider).incomeSourcesDao);

@Riverpod(keepAlive: true)
BudgetRepository budgetRepository(Ref ref) => BudgetRepositoryImpl(
  ref.watch(appDatabaseProvider).budgetsDao,
  currency: ref.watch(appCurrencyProvider),
);

@Riverpod(keepAlive: true)
ValidateIncomeSource validateIncomeSource(Ref ref) =>
    const ValidateIncomeSource();

@Riverpod(keepAlive: true)
AddIncomeSource addIncomeSource(Ref ref) => AddIncomeSource(
  ref.watch(incomeSourceRepositoryProvider),
  ref.watch(idGeneratorProvider),
  ref.watch(validateIncomeSourceProvider),
);

@Riverpod(keepAlive: true)
EditIncomeSource editIncomeSource(Ref ref) => EditIncomeSource(
  ref.watch(incomeSourceRepositoryProvider),
  ref.watch(validateIncomeSourceProvider),
);

@Riverpod(keepAlive: true)
DeleteIncomeSource deleteIncomeSource(Ref ref) =>
    DeleteIncomeSource(ref.watch(incomeSourceRepositoryProvider));

@Riverpod(keepAlive: true)
WatchIncomeSources watchIncomeSources(Ref ref) =>
    WatchIncomeSources(ref.watch(incomeSourceRepositoryProvider));

@Riverpod(keepAlive: true)
SetMonthlyBudget setMonthlyBudget(Ref ref) =>
    SetMonthlyBudget(ref.watch(budgetRepositoryProvider));

@Riverpod(keepAlive: true)
WatchBudgets watchBudgets(Ref ref) =>
    WatchBudgets(ref.watch(budgetRepositoryProvider));

@Riverpod(keepAlive: true)
ComputeBudgetOverview computeBudgetOverview(Ref ref) =>
    const ComputeBudgetOverview();

@Riverpod(keepAlive: true)
ComputeMoneyAvailable computeMoneyAvailable(Ref ref) =>
    const ComputeMoneyAvailable();
