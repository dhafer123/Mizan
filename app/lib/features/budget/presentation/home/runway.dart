import '../../domain/value_objects/run_out_forecast.dart';

/// Where a forecast's dates fall on Home's runway bar: today at 0, its end at
/// 1. The end is the next income when it comes before the forecast's
/// horizon (the question is "do I make it to payday?"), else the horizon.
///
/// Fractions of a bar, not money: doubles are fine here.
class Runway {
  const Runway({
    required this.end,
    required this.endsAtIncome,
    this.runOut,
    this.riskStart,
    this.riskEnd,
  });

  factory Runway.of(ProjectedForecast forecast, {DateTime? nextIncome}) {
    final today = forecast.today;
    final incomeAhead =
        nextIncome != null &&
        nextIncome.isAfter(today) &&
        !nextIncome.isAfter(forecast.horizonEnd);
    final end = incomeAhead ? nextIncome : forecast.horizonEnd;
    final span = end.difference(today).inDays;

    double? at(DateTime? day) => day == null || day.isAfter(end)
        ? null
        : (day.difference(today).inDays / span).clamp(0.0, 1.0);

    final riskStart = at(forecast.earliest);
    return Runway(
      end: end,
      endsAtIncome: incomeAhead,
      runOut: at(forecast.runOut),
      riskStart: riskStart,
      riskEnd: riskStart == null ? null : at(forecast.latest) ?? 1,
    );
  }

  /// The bar's last day: the next income, or the forecast's horizon.
  final DateTime end;
  final bool endsAtIncome;

  /// Where the money runs out at the expected rate; null when it lasts past
  /// [end].
  final double? runOut;

  /// The low–high range of the run-out, where it falls before [end].
  final double? riskStart;
  final double? riskEnd;

  /// The money lasts to [end] even at the faster rate.
  bool get isSafe => runOut == null && riskStart == null;
}
