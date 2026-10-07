import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../expenses/presentation/expense_sheet/expense_sheet.dart';
import '../../../expenses/presentation/shared/failure_message.dart';
import '../../../sync/presentation/sync_status_button.dart';
import '../../domain/value_objects/dashboard.dart';
import 'dashboard_provider.dart';
import 'forecast_card.dart';
import 'money_left_card.dart';
import 'recent_expenses_card.dart';
import 'top_categories_card.dart';

/// The dashboard: money left this month, days until the next income, when
/// the money runs out, where it went, and the newest expenses.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mizan'),
        actions: [
          const SyncStatusButton(),
          IconButton(
            onPressed: () => context.push(AppRoutes.expenses),
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Expenses',
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.groups),
            icon: const Icon(Icons.groups_outlined),
            tooltip: 'Groups',
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.budget),
            icon: const Icon(Icons.savings_outlined),
            tooltip: 'Budget',
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: ref
          .watch(dashboardProvider)
          .when(
            // Keep showing the last numbers while a change recomputes.
            skipLoadingOnReload: true,
            data: (dashboard) => _DashboardBody(dashboard: dashboard),
            error: (error, _) => _LoadError(
              message: failureMessage(error),
              onRetry: () => retryDashboard(ref),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExpenseSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Clear of the add button and the system inset.
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        88 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        MoneyLeftCard(dashboard: dashboard),
        const SizedBox(height: 12),
        ForecastCard(owedToMe: dashboard.owedToMe),
        const SizedBox(height: 12),
        TopCategoriesCard(dashboard: dashboard),
        const SizedBox(height: 12),
        RecentExpensesCard(expenses: dashboard.recent),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
