import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';
import 'spend_rate.dart';

part 'run_out_forecast.freezed.dart';

/// When money left is expected to run out. Computed, never stored.
@freezed
sealed class RunOutForecast with _$RunOutForecast {
  /// A day-by-day projection from today. Dates are calendar days (UTC
  /// midnight); a null date means the money lasts past [horizonEnd].
  const factory RunOutForecast.projected({
    required DateTime today,

    /// The last day projected.
    required DateTime horizonEnd,

    /// What the projection starts from: money left, plus what's owed to me
    /// when asked for.
    required Money start,

    /// The first day the balance goes below 0 at the expected rate. Today
    /// if it already is.
    DateTime? runOut,

    /// At the faster rate: never after [runOut].
    DateTime? earliest,

    /// At the slower rate: never before [runOut].
    DateTime? latest,

    /// The expected daily spending used.
    required SpendRate rate,

    /// Fewer than `ForecastRunOut.coldStartDays` days of history: the rate
    /// is the monthly budget spread over the month, and the range is that
    /// one date.
    required bool coldStart,
  }) = ProjectedForecast;

  /// Too little history to learn a rate, and no budget to use instead.
  const factory RunOutForecast.needsData({required int daysOfData}) =
      ForecastNeedsData;
}
