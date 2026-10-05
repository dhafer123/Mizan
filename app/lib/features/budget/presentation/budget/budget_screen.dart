import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/core_providers.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/clock/calendar_day.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../expenses/presentation/categories/category_sheet.dart';
import '../../../expenses/presentation/expense_list/selected_month.dart';
import '../../../expenses/presentation/shared/category_icon.dart';
import '../../../expenses/presentation/shared/failure_message.dart';
import '../../../expenses/presentation/shared/month_bar.dart';
import '../../domain/value_objects/budget_overview.dart';
import '../../domain/value_objects/category_budget.dart';
import 'budget_limit_sheet.dart';
import 'budget_providers.dart';
import 'budget_screen_data.dart';

const _money = MoneyFormatter();

/// A month's money: income against spending, the overall budget, and each
/// category's spending against its limit.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.income),
            icon: const Icon(Icons.payments_outlined),
            tooltip: 'Income',
          ),
        ],
      ),
      body: Column(
        children: [
          MonthBar(month: month),
          const Divider(height: 1),
          Expanded(
            child: ref
                .watch(budgetScreenProvider(month))
                .when(
                  // Keep showing the last numbers while a change recomputes.
                  skipLoadingOnReload: true,
                  data: (data) => _BudgetBody(data: data),
                  error: (error, _) => _LoadError(
                    message: failureMessage(error),
                    onRetry: () => retryBudgetScreen(ref, month),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
          ),
        ],
      ),
    );
  }
}

class _BudgetBody extends StatelessWidget {
  const _BudgetBody({required this.data});

  final BudgetScreenData data;

  @override
  Widget build(BuildContext context) {
    final overview = data.overview;
    return ListView(
      // An explicit padding replaces the system inset, so add it back.
      padding: EdgeInsets.only(
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _AvailableCard(data: data),
        _TotalBudgetCard(overview: overview),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'By category',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final line in overview.categories) _CategoryLine(line: line),
      ],
    );
  }
}

class _AvailableCard extends ConsumerWidget {
  const _AvailableCard({required this.data});

  final BudgetScreenData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final available = data.available;
    final next = available.next;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Money available', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              _money.format(available.available),
              key: const ValueKey('available'),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: available.available.isNegative
                    ? theme.colorScheme.error
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            _AmountRow(label: 'Income', amount: available.income),
            _AmountRow(label: 'Spent', amount: available.spent),
            if (data.isCurrentMonth && next != null) ...[
              const SizedBox(height: 8),
              Text(
                _nextIncomeText(context, ref, next.source.name, next.date),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (!data.hasIncome) ...[
              const SizedBox(height: 8),
              Text(
                'Add your income to see what you can spend.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => context.push(AppRoutes.income),
                child: const Text('Add income'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _nextIncomeText(
    BuildContext context,
    WidgetRef ref,
    String name,
    DateTime date,
  ) {
    final today = ref.read(clockProvider).now().calendarDay;
    final days = date.difference(today).inDays;
    final when = switch (days) {
      0 => 'today',
      1 => 'tomorrow',
      _ =>
        'on ${MaterialLocalizations.of(context).formatMediumDate(DateTime(date.year, date.month, date.day))} '
            '(in $days days)',
    };
    return 'Next income: $name $when';
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.amount});

  final String label;
  final Money amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(_money.format(amount)),
      ],
    );
  }
}

class _TotalBudgetCard extends StatelessWidget {
  const _TotalBudgetCard({required this.overview});

  final BudgetOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = overview.totalLimit;
    final left = overview.totalLeft;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Monthly budget',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => showBudgetLimitSheet(
                    context,
                    month: overview.month,
                    current: limit,
                  ),
                  child: Text(limit == null ? 'Set budget' : 'Edit'),
                ),
              ],
            ),
            if (limit == null || left == null)
              Text('${_money.format(overview.spent)} spent · no monthly budget')
            else ...[
              Text(
                '${_money.format(overview.spent)} of ${_money.format(limit)}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _UsedBar(percent: overview.usedPercent!, over: overview.isOver),
              const SizedBox(height: 4),
              _LeftText(left: left),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryLine extends StatelessWidget {
  const _CategoryLine({required this.line});

  final CategoryBudget line;

  @override
  Widget build(BuildContext context) {
    final category = line.category;
    final limit = line.limit;
    final left = line.left;

    return ListTile(
      onTap: category == null
          ? null
          : () => showCategorySheet(context, category: category),
      leading: CircleAvatar(
        child: ExcludeSemantics(
          child: Icon(categoryIcon(category?.icon ?? '')),
        ),
      ),
      title: Text(category?.name ?? 'Uncategorised'),
      subtitle: limit == null || left == null
          ? Text('${_money.format(line.spent)} spent · no limit')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _UsedBar(percent: line.usedPercent!, over: line.isOver),
                const SizedBox(height: 4),
                Text('${_money.format(line.spent)} of ${_money.format(limit)}'),
                _LeftText(left: left),
              ],
            ),
    );
  }
}

/// Progress towards a limit: amber from 80% (the alert threshold), red when
/// over.
class _UsedBar extends StatelessWidget {
  const _UsedBar({required this.percent, required this.over});

  final int percent;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LinearProgressIndicator(
      value: percent >= 100 ? 1 : percent / 100,
      color: over
          ? colors.error
          : percent >= 80
          ? Colors.amber.shade700
          : null,
      minHeight: 6,
      borderRadius: BorderRadius.circular(3),
      semanticsLabel: '$percent% used',
    );
  }
}

class _LeftText extends StatelessWidget {
  const _LeftText({required this.left});

  final Money left;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return left.isNegative
        ? Text(
            'Over by ${_money.format(-left)}',
            style: TextStyle(color: theme.colorScheme.error),
          )
        : Text('${_money.format(left)} left');
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
