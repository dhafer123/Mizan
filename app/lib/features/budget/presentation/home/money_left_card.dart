import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/animated_bar.dart';
import '../../../../app/widgets/animated_money.dart';
import '../../../../core/money/money_formatter.dart';
import '../../domain/value_objects/dashboard.dart';

const _money = MoneyFormatter();

/// Home's hero: money left this month in big numbers on the brand gradient,
/// income and spending, the overall budget, group money, and the days until
/// money comes in next.
class MoneyLeftCard extends StatelessWidget {
  const MoneyLeftCard({required this.dashboard, super.key});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hero = AppColors.of(context);
    final available = dashboard.available;
    final left = available.available;
    final overview = dashboard.overview;
    final budgetLeft = overview.totalLeft;
    final next = available.next;
    final days = dashboard.daysToNextIncome;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: hero.onHeroMuted);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [hero.heroStart, hero.heroEnd],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: hero.onHero),
            child: IconTheme.merge(
              data: IconThemeData(color: hero.onHero),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Read as one heading: "Money left this month, 120.000 DT".
                  MergeSemantics(
                    child: Semantics(
                      header: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Money left this month',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: hero.onHeroMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedMoney(
                            left,
                            textKey: const ValueKey('moneyLeft'),
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: left.isNegative
                                  ? hero.heroNegative
                                  : hero.onHero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_money.format(available.income)} income · '
                    '${_money.format(available.spent)} spent',
                    style: muted,
                  ),
                  if (overview.totalLimit case final limit?
                      when budgetLeft != null) ...[
                    const SizedBox(height: 16),
                    // The bar repeats the sentence under it.
                    ExcludeSemantics(
                      child: AnimatedBar(
                        value: (overview.usedPercent ?? 0) / 100,
                        minHeight: 8,
                        color: overview.isOver
                            ? hero.heroNegative
                            : hero.heroAccent,
                        backgroundColor: hero.onHero.withValues(alpha: 0.18),
                      ),
                    ),
                    const SizedBox(height: 6),
                    overview.isOver
                        ? Text(
                            'Over budget by ${_money.format(-budgetLeft)}',
                            style: TextStyle(
                              color: hero.heroNegative,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : Text(
                            '${_money.format(budgetLeft)} left of your '
                            '${_money.format(limit)} budget',
                            style: muted,
                          ),
                  ],
                  // Group money: not spending and not part of the money left.
                  if (_groupPills(context) case final pills
                      when pills.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: pills),
                  ],
                  const SizedBox(height: 16),
                  _NextIncome(
                    nextName: next?.source.name,
                    days: days,
                    noIncome: available.income.isZero,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _groupPills(BuildContext context) => [
    if (dashboard.owedToMe case final owed? when owed.isPositive)
      _Pill(
        key: const ValueKey('owedToMe'),
        icon: Icons.call_received,
        text: 'Owed to you in groups: ${_money.format(owed)}',
      ),
    if (dashboard.iOwe case final owe? when owe.isPositive)
      _Pill(
        key: const ValueKey('iOwe'),
        icon: Icons.call_made,
        text: 'You owe in groups: ${_money.format(owe)}',
      ),
  ];
}

/// A small translucent capsule on the hero gradient.
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final hero = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: hero.onHero.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 16)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: hero.onHero),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextIncome extends StatelessWidget {
  const _NextIncome({
    required this.nextName,
    required this.days,
    required this.noIncome,
  });

  final String? nextName;
  final int? days;
  final bool noIncome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hero = AppColors.of(context);
    if (nextName case final name? when days != null) {
      return Row(
        children: [
          const ExcludeSemantics(child: Icon(Icons.event_outlined)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(switch (days) {
              0 => 'Income today: $name',
              1 => 'Next income tomorrow: $name',
              _ => 'Next income in $days days: $name',
            }, style: theme.textTheme.titleSmall?.copyWith(color: hero.onHero)),
          ),
        ],
      );
    }
    if (noIncome) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add your income to see what you can spend.'),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: hero.onHero,
                foregroundColor: hero.heroEnd,
              ),
              onPressed: () => context.push(AppRoutes.income),
              child: const Text('Add income'),
            ),
          ),
        ],
      );
    }
    return Text(
      'No income date scheduled.',
      style: TextStyle(color: hero.onHero),
    );
  }
}
