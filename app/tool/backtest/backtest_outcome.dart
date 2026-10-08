/// How far a backtest day's error is known (see `BacktestDay`).
enum BacktestOutcome {
  /// The error is known: both dates were seen, or both lie past the horizon.
  exact,

  /// Only a lower bound is known: one side ran out and the other hadn't by
  /// the end of what was seen.
  atLeast,

  /// Nothing is known: neither ran out before the data ended, and the
  /// horizon goes past it.
  censored,

  /// Money left was already below 0: nothing to forecast.
  alreadyOut,

  /// Too little history and no budget: the forecast gave no date.
  noForecast,
}
