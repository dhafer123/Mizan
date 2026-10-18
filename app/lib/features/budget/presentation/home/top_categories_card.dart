import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/animated_money.dart';
import '../../../../app/widgets/large_text.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../expenses/presentation/shared/category_color.dart';
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
    // Each category in its own colour, as everywhere else; the rest grey.
    final palette = AppColors.of(context);
    final top = dashboard.topCategories;
    final other = dashboard.otherSpent;

    final slices = [
      for (final line in top)
        _Slice(
          name: line.category?.name ?? 'Uncategorised',
          icon: categoryIcon(line.category?.icon ?? ''),
          spent: line.spent,
          color: categoryColor(context, line.category),
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
        onTap: () => context.go(AppRoutes.budget),
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
              else ...[
                // The donut on top, the legend at full width under it, so
                // names and amounts never squeeze beside the chart.
                Center(
                  child: _Donut(
                    slices: slices,
                    total: dashboard.overview.spent,
                  ),
                ),
                const SizedBox(height: 16),
                legend,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut({required this.slices, required this.total});

  final List<_Slice> slices;

  /// The month's spending, in the hole (unless text is too large for it).
  final Money total;

  static const _size = 156.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final sum = total.minorUnits.toDouble();
    // Sweeps round from the top when it first shows: an empty slice holds
    // the part not drawn yet. Later changes use the chart's own animation.
    Widget chart(double drawn) => PieChart(
      duration: still || drawn < 1
          ? Duration.zero
          : const Duration(milliseconds: 300),
      PieChartData(
        sections: [
          for (final slice in slices)
            PieChartSectionData(
              value: slice.spent.minorUnits.toDouble(),
              color: slice.color,
              radius: 20,
              showTitle: false,
            ),
          if (drawn < 1)
            PieChartSectionData(
              value: sum * (1 - drawn) / drawn.clamp(0.001, 1),
              color: Colors.transparent,
              radius: 20,
              showTitle: false,
            ),
        ],
        centerSpaceRadius: 54,
        sectionsSpace: 2,
        startDegreeOffset: -90,
        pieTouchData: PieTouchData(enabled: false),
      ),
    );

    return SizedBox.square(
      dimension: _size,
      // The legend reads out the same numbers, and the hero the total.
      child: ExcludeSemantics(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (still)
              chart(1)
            else
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, drawn, _) => chart(drawn),
              ),
            if (!context.hasLargeText)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedMoney(total, style: theme.textTheme.titleSmall),
                  Text(
                    'spent',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          ],
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
            // Names get more of the row than amounts.
            flex: 2,
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
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_money.format(slice.spent), textAlign: TextAlign.end),
                    Text('$percent%', style: theme.textTheme.bodySmall),
                  ],
                ),
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
