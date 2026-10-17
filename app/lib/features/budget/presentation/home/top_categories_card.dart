import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/large_text.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../expenses/presentation/shared/category_icon.dart';
import '../../domain/value_objects/dashboard.dart';

const _money = MoneyFormatter();

/// Where the month's money went: a donut of the top categories and the rest,
/// with a legend. Tap through to the budget screen.
class TopCategoriesCard extends StatelessWidget {
  const TopCategoriesCard({required this.dashboard, super.key});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Slice colours in rank order; "other" is always grey.
    final palette = AppColors.of(context);
    final top = dashboard.topCategories;
    final other = dashboard.otherSpent;

    final slices = [
      for (final (i, line) in top.indexed)
        _Slice(
          name: line.category?.name ?? 'Uncategorised',
          icon: categoryIcon(line.category?.icon ?? ''),
          spent: line.spent,
          color: palette.chart[i % palette.chart.length],
          overLimit: line.isOver,
        ),
      if (other.isPositive)
        _Slice(
          name: 'Other categories',
          icon: Icons.more_horiz,
          spent: other,
          color: palette.chartOther,
        ),
    ];

    final legend = Column(
      children: [
        for (final slice in slices)
          _LegendRow(
            slice: slice,
            percent: dashboard.sharePercent(slice.spent),
          ),
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.budget),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Top categories',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
              if (dashboard.isEmptyMonth)
                const _NoSpending()
              else if (context.hasLargeText)
                // No room beside the chart at this size: legend below it.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _Donut(slices: slices)),
                    const SizedBox(height: 12),
                    legend,
                  ],
                )
              else
                Row(
                  children: [
                    _Donut(slices: slices),
                    const SizedBox(width: 16),
                    Expanded(child: legend),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut({required this.slices});

  final List<_Slice> slices;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 120,
      // The legend reads out the same numbers.
      child: ExcludeSemantics(
        child: PieChart(
          PieChartData(
            sections: [
              for (final slice in slices)
                PieChartSectionData(
                  value: slice.spent.minorUnits.toDouble(),
                  color: slice.color,
                  radius: 22,
                  showTitle: false,
                ),
            ],
            centerSpaceRadius: 34,
            sectionsSpace: 2,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(enabled: false),
          ),
        ),
      ),
    );
  }
}

class _Slice {
  const _Slice({
    required this.name,
    required this.icon,
    required this.spent,
    required this.color,
    this.overLimit = false,
  });

  final String name;
  final IconData icon;
  final Money spent;
  final Color color;
  final bool overLimit;
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, required this.percent});

  final _Slice slice;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // At large text the amount goes under the name, or it would crowd it out.
    final stacked = context.hasLargeText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: slice.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Icon(slice.icon, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slice.name, overflow: TextOverflow.ellipsis),
                if (stacked) Text('${_money.format(slice.spent)} · $percent%'),
                if (slice.overLimit)
                  Text(
                    'Over its limit',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          if (!stacked)
            // Shrinks (and wraps) before it would overflow a long name.
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_money.format(slice.spent), textAlign: TextAlign.end),
                  Text('$percent%', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NoSpending extends StatelessWidget {
  const _NoSpending();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.pie_chart_outline,
          size: 40,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Text(
            'No spending yet this month. Add an expense to see where your '
            'money goes.',
          ),
        ),
      ],
    );
  }
}
