# ADR 0014: The forecast backtest replays the forecast's own accounting and counts what it can't see

- Status: accepted
- Date: 2026-10-08
- Task: 5.3 (ARCHITECTURE.md §7)

## Context

§7 says: at each day *d*, forecast the run-out date using only data before *d*, compare it with the actual date, and report the mean absolute error in days. Three questions came up:

1. **What is the "actual" run-out date?** The app has no bank balance. The forecast's balance is Home's money left plus later months' income, carried over (ADR 0012). The real money left resets every month.
2. **What if the actual date isn't in the data?** The forecast looks 60 days ahead, and the test data covers only 4+ weeks. Often money hasn't run out by the end of the data.
3. **Where does the data come from?** It is on the phone. The app already exports expenses as CSV (task 2.6), but not incomes.

## Decision

- **Same accounting on both sides.** At the end of each day *d*, the backtest forecasts from expenses dated up to *d*. Money left counts *d*'s spending, as Home did that evening. The actual date comes from `ForecastRunOut.runOutDay` (pulled out of the forecast for this). It uses the same start, income and carry-over, but each day spends what was really spent. The error then measures the spending guess alone, not a difference in bookkeeping.
- **Score what's known, and count the rest.** Each day is one of:
  - *exact*: both dates seen, or both past the 60-day horizon (0 error);
  - *at least*: one side ran out and the other hadn't by the end of the data or the horizon. That end, plus one day, gives a lower bound on the error;
  - *censored*: neither ran out before the data ended. Not scored;
  - *already out* (money left below 0) and *no forecast* (cold start without a budget). Not scored.

  The headline is the MAE over exact days. Next to it go the MAE with the lower bounds (itself a lower bound), the bias (signed mean, + = too late) and how often the real date fell inside the range. Cold-start days are reported both with and without.
- **Input is the app's CSV export**, with `--income` and `--budget` flags for what the CSV doesn't hold. It is a Dart script in `app/tool/`, so it runs the real forecast code with `dart run`, with no copy of it in Python.

## Consequences

- With only a few weeks of data, many days are censored, and the number of exact days matters as much as the MAE. Both go into METRICS.md.
- Incomes are today's, applied to the whole history, and group shares aren't in the CSV. Fine for one person's 4–6 weeks. A longer study would read the database instead.
- Expenses entered late (on a later day than they're dated) are seen "early" by the replay. The CSV doesn't hold when an expense was entered.
