import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../expenses/presentation/shared/failure_message.dart';
import '../../domain/usecases/forecast_run_out.dart';
import '../../domain/value_objects/run_out_forecast.dart';
import 'forecast_provider.dart';

const _money = MoneyFormatter();

/// When money left is expected to run out, with a range, what the rate is
/// based on, and the "include money owed to me" switch.
class ForecastCard extends ConsumerWidget {
  const ForecastCard({this.owedToMe, super.key});

  /// What others owe me in groups; the switch shows only when positive.
  final Money? owedToMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final forecast = ref.watch(forecastProvider);
    final includeOwed = ref.watch(includeOwedInForecastProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Forecast', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            forecast.when(
              skipLoadingOnReload: true,
              data: (f) => switch (f) {
                ProjectedForecast() => _Projected(forecast: f),
                ForecastNeedsData(:final daysOfData) => _NeedsData(
                  daysOfData: daysOfData,
                ),
              },
              error: (error, _) => Row(
                children: [
                  Expanded(child: Text(failureMessage(error))),
                  TextButton(
                    onPressed: () => retryForecast(ref),
                    child: const Text('Try again'),
                  ),
                ],
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
  const _Projected({required this.forecast});

  final ProjectedForecast forecast;

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
        const SizedBox(height: 4),
        Text(basis, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _NeedsData extends StatelessWidget {
  const _NeedsData({required this.daysOfData});

  final int daysOfData;

  @override
  Widget build(BuildContext context) {
    final left = ForecastRunOut.coldStartDays - daysOfData;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Keep logging: the forecast starts after '
            '${ForecastRunOut.coldStartDays} days of spending '
            '($left to go). Or set a monthly budget to see one now.',
            key: const ValueKey('forecastNeedsData'),
          ),
        ),
        TextButton(
          onPressed: () => context.push(AppRoutes.budget),
          child: const Text('Set budget'),
        ),
      ],
    );
  }
}

/// A calendar day (UTC midnight) as a short local date, e.g. "Oct 21".
String _day(BuildContext context, DateTime day) => MaterialLocalizations.of(
  context,
).formatShortMonthDay(DateTime(day.year, day.month, day.day));
