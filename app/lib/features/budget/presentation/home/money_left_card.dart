import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/money/money_formatter.dart';
import '../../domain/value_objects/dashboard.dart';

const _money = MoneyFormatter();

/// Income minus spending this month, the overall budget, and the days until
/// money comes in next.
class MoneyLeftCard extends StatelessWidget {
  const MoneyLeftCard({required this.dashboard, super.key});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final available = dashboard.available;
    final left = available.available;
    final overview = dashboard.overview;
    final budgetLeft = overview.totalLeft;
    final next = available.next;
    final days = dashboard.daysToNextIncome;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Money left this month', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              _money.format(left),
              key: const ValueKey('moneyLeft'),
              style: theme.textTheme.displaySmall?.copyWith(
                color: left.isNegative ? colors.error : null,
              ),
            ),
            Text(
              '${_money.format(available.income)} income · '
              '${_money.format(available.spent)} spent',
              style: theme.textTheme.bodyMedium,
            ),
            // Group money: not spending and not part of the money left.
            if (dashboard.owedToMe case final owed? when owed.isPositive)
              Text(
                'Owed to you in groups: ${_money.format(owed)}',
                key: const ValueKey('owedToMe'),
                style: theme.textTheme.bodyMedium,
              ),
            if (dashboard.iOwe case final owe? when owe.isPositive)
              Text(
                'You owe in groups: ${_money.format(owe)}',
                key: const ValueKey('iOwe'),
                style: theme.textTheme.bodyMedium,
              ),
            if (overview.totalLimit case final limit? when budgetLeft != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: overview.isOver
                    ? Text(
                        'Over budget by ${_money.format(-budgetLeft)}',
                        style: TextStyle(
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Text(
                        '${_money.format(budgetLeft)} left of your '
                        '${_money.format(limit)} budget',
                      ),
              ),
            const Divider(height: 24),
            if (next != null && days != null)
              Row(
                children: [
                  Icon(Icons.event_outlined, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(switch (days) {
                      0 => 'Income today: ${next.source.name}',
                      1 => 'Next income tomorrow: ${next.source.name}',
                      _ => 'Next income in $days days: ${next.source.name}',
                    }, style: theme.textTheme.titleSmall),
                  ),
                ],
              )
            else if (available.income.isZero)
              Row(
                children: [
                  const Expanded(
                    child: Text('Add your income to see what you can spend.'),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.income),
                    child: const Text('Add income'),
                  ),
                ],
              )
            else
              const Text('No income date scheduled.'),
          ],
        ),
      ),
    );
  }
}
