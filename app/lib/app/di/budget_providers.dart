import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/budget/data/platform/local_alert_notifier.dart';
import '../../features/budget/data/repositories/alert_log_impl.dart';
import '../../features/budget/data/repositories/budget_repository_impl.dart';
import '../../features/budget/data/repositories/income_source_repository_impl.dart';
import '../../features/budget/domain/repositories/alert_log.dart';
import '../../features/budget/domain/repositories/alert_notifier.dart';
import '../../features/budget/domain/repositories/budget_repository.dart';
import '../../features/budget/domain/repositories/income_source_repository.dart';
import '../../features/budget/domain/usecases/add_income_source.dart';
import '../../features/budget/domain/usecases/compute_budget_alerts.dart';
import '../../features/budget/domain/usecases/compute_budget_overview.dart';
import '../../features/budget/domain/usecases/compute_dashboard.dart';
import '../../features/budget/domain/usecases/compute_money_available.dart';
import '../../features/budget/domain/usecases/delete_income_source.dart';
import '../../features/budget/domain/usecases/edit_income_source.dart';
import '../../features/budget/domain/usecases/forecast_run_out.dart';
import '../../features/budget/domain/usecases/request_alert_permission.dart';
import '../../features/budget/domain/usecases/send_budget_alerts.dart';
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

@Riverpod(keepAlive: true)
ComputeDashboard computeDashboard(Ref ref) => ComputeDashboard(
  overview: ref.watch(computeBudgetOverviewProvider),
  available: ref.watch(computeMoneyAvailableProvider),
);

@Riverpod(keepAlive: true)
ForecastRunOut forecastRunOut(Ref ref) => const ForecastRunOut();

@Riverpod(keepAlive: true)
AlertLog alertLog(Ref ref) =>
    AlertLogImpl(ref.watch(appDatabaseProvider).sentAlertsDao);

/// Override with a fake in tests.
@Riverpod(keepAlive: true)
AlertNotifier alertNotifications(Ref ref) =>
    LocalAlertNotifier(ref.watch(localNotificationsProvider));

@Riverpod(keepAlive: true)
ComputeBudgetAlerts computeBudgetAlerts(Ref ref) => const ComputeBudgetAlerts();

/// One instance per isolate, so its checks run one at a time.
@Riverpod(keepAlive: true)
SendBudgetAlerts sendBudgetAlerts(Ref ref) => SendBudgetAlerts(
  ref.watch(alertLogProvider),
  ref.watch(alertNotificationsProvider),
  ref.watch(clockProvider),
);

@Riverpod(keepAlive: true)
RequestAlertPermission requestAlertPermission(Ref ref) =>
    RequestAlertPermission(ref.watch(alertNotificationsProvider));
