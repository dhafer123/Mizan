import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/widgets/text_with_action.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../expenses/presentation/shared/failure_message.dart';
import '../../domain/usecases/forecast_run_out.dart';
import '../../domain/value_objects/run_out_forecast.dart';
import 'forecast_provider.dart';
import 'runway.dart';

const _money = MoneyFormatter();

/// When money left is expected to run out: a "runway" bar from today to the
/// next income, the date with its range, what the rate is based on, and the
/// "include money owed to me" switch.
class ForecastCard extends ConsumerWidget {
  const ForecastCard({this.owedToMe, this.nextIncome, super.key});

  /// What others owe me in groups; the switch shows only when positive.
  final Money? owedToMe;

  /// The next income's day, where the runway ends.
  final DateTime? nextIncome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final includeOwed = ref.watch(includeOwedInForecastProvider);
    final forecast = ref.watch(forecastProvider(includeOwed: includeOwed));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text('Forecast', style: theme.textTheme.labelLarge),
            ),
            const SizedBox(height: 8),
            forecast.when(
              skipLoadingOnReload: true,
              data: (f) => switch (f) {
                ProjectedForecast() => _Projected(
                  forecast: f,
                  nextIncome: nextIncome,
                ),
                ForecastNeedsData(:final daysOfData) => _NeedsData(
                  daysOfData: daysOfData,
                ),
              },
              error: (error, _) => TextWithAction(
                text: failureMessage(error),
                action: TextButton(
                  onPressed: () => retryForecast(ref),
                  child: const Text('Try again'),
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            ),
            if (owedToMe case final owed? when owed.isPositive)
              SwitchListTile(
                key: const ValueKey('includeOwed'),
                contentPadding: EdgeInsets.zero,
                title: Text('Count the ${_money.format(owed)} owed to me'),
                value: includeOwed,
                onChanged: (value) =>
                    ref.read(includeOwedInForecastProvider.notifier).set(value),
              ),
          ],
        ),
      ),
    );
  }
}

class _Projected extends StatelessWidget {
  const _Projected({required this.forecast, this.nextIncome});

  final ProjectedForecast forecast;
  final DateTime? nextIncome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final f = forecast;
    String day(DateTime d) => _day(context, d);

    final (headline, warn) = switch (f.runOut) {
      null => ('Your money lasts past ${day(f.horizonEnd)}', false),
      final d when d == f.today => (
        'Your money for this month has run out',
        true,
      ),
      final d => ('Money runs out around ${day(d)}', true),
    };
    final range = switch ((f.earliest, f.latest)) {
      _ when f.runOut == null || f.runOut == f.today => null,
      (final a?, final b?) when a != b => 'Between ${day(a)} and ${day(b)}',
      (final a?, null) => 'Between ${day(a)} and after ${day(f.horizonEnd)}',
      _ => null,
    };
    final basis = f.coldStart
        ? 'Based on your monthly budget until you have '
              '${ForecastRunOut.coldStartDays} days of spending.'
        : f.rate.weekday == f.rate.weekend
        ? 'Based on spending ${_money.format(f.rate.weekday)} a day.'
        : 'Based on spending ${_money.format(f.rate.weekday)} on weekdays '
              'and ${_money.format(f.rate.weekend)} on weekend days.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              warn ? Icons.trending_down : Icons.check_circle_outline,
              color: warn ? colors.error : colors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                headline,
                key: const ValueKey('forecastHeadline'),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        if (range != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(range, key: const ValueKey('forecastRange')),
          ),
        const SizedBox(height: 16),
        _RunwayBar(runway: Runway.of(f, nextIncome: nextIncome)),
        const SizedBox(height: 12),
        Text(basis, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Today to the next income (or the horizon) as a bar: filled while the
/// money lasts, red after it runs out, the likely range shaded. The text
/// above says the same, so screen readers skip it.
class _RunwayBar extends StatelessWidget {
  const _RunwayBar({required this.runway});

  final Runway runway;

  static const _height = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final small = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final lasts = runway.runOut ?? 1;

    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _height + 8,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                Widget span(double from, double to, Decoration decoration) =>
                    Positioned(
                      left: width * from,
                      width: width * (to - from),
                      top: 4,
                      height: _height,
                      child: DecoratedBox(decoration: decoration),
                    );
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    span(
                      0,
                      1,
                      BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(_height / 2),
                      ),
                    ),
                    if (lasts < 1)
                      span(
                        lasts,
                        1,
                        BoxDecoration(
                          color: colors.error.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(_height / 2),
                        ),
                      ),
                    if (lasts > 0)
                      span(
                        0,
                        lasts,
                        BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.primary, colors.secondary],
                          ),
                          borderRadius: BorderRadius.circular(_height / 2),
                        ),
                      ),
                    if (runway.riskStart case final from?)
                      span(
                        from,
                        runway.riskEnd ?? 1,
                        BoxDecoration(
                          color: colors.error.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(_height / 2),
                        ),
                      ),
                    if (runway.runOut case final at?)
                      Positioned(
                        left: (width * at - 10).clamp(0, width - 20),
                        top: 0,
                        width: 20,
                        height: 20,
                        child: DecoratedBox(
                          key: const ValueKey('runwayRunOut'),
                          decoration: BoxDecoration(
                            color: colors.error,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.surface, width: 3),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('Today', style: small)),
              if (runway.endsAtIncome) ...[
                Icon(Icons.payments_outlined, size: 16, color: colors.primary),
                const SizedBox(width: 4),
              ],
              Text(
                runway.endsAtIncome
                    ? 'Payday · ${_day(context, runway.end)}'
                    : _day(context, runway.end),
                style: small,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NeedsData extends StatelessWidget {
  const _NeedsData({required this.daysOfData});

  final int daysOfData;

  @override
  Widget build(BuildContext context) {
    final left = ForecastRunOut.coldStartDays - daysOfData;
    return TextWithAction(
      key: const ValueKey('forecastNeedsData'),
      text:
          'Keep logging: the forecast starts after '
          '${ForecastRunOut.coldStartDays} days of spending '
          '($left to go). Or set a monthly budget to see one now.',
      action: TextButton(
        onPressed: () => context.go(AppRoutes.budget),
        child: const Text('Set budget'),
      ),
    );
  }
}

/// A calendar day (UTC midnight) as a short local date, e.g. "Oct 21".
String _day(BuildContext context, DateTime day) => MaterialLocalizations.of(
  context,
).formatShortMonthDay(DateTime(day.year, day.month, day.day));
