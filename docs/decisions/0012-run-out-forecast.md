# ADR 0012: The run-out forecast starts from money left, and its range comes from weekly totals

- Status: accepted
- Date: 2026-10-07
- Task: 5.1 (ARCHITECTURE.md §7)

## Context

§7 describes the forecast: start from the current balance minus upcoming recurring costs, spend a weighted daily average split into weekdays and weekends, add scheduled income, and stop when the balance goes below 0. The range comes from the 25th and 75th percentile of daily spend. Building it raised three questions:

1. **What is the "current balance"?** The app has no account balance. Home's "money left" is this month's income minus this month's spending, with no carry-over.
2. **Where do recurring costs come from?** There is no recurring-cost entity. Detecting them is v2.
3. **Do daily percentiles give a useful range?** A student who shops twice a week spends nothing on most days. The 25th percentile of daily spend is then 0, and the "low" projection never runs out.

## Decision

- **Start from Home's money left** (decided with the user). It already counts all of this month's income, whatever its payday. So the projection adds only income from *later* months:
  - monthly sources on their payday;
  - one-offs on their date;
  - irregular sources on the 1st, since their amount is a monthly estimate.

  The forecast then agrees with what Home shows. It doesn't count savings or last month's leftover, because the app doesn't know about them.
- **Recurring costs are an input only for now** (decided with the user). `ForecastRunOut` takes `RecurringCost`s (amount, day of month, optional category), subtracts each on its day, and leaves its category out of the daily average so it isn't counted twice. The app passes none yet. Rent paid as an expense still counts through the average.
- **The range comes from 7-day totals.** `EstimateDailySpend` takes every 7-day window in the history and finds the 25th and 75th percentile of their totals (nearest rank). Each percentile divided by the mean weekly total scales the expected weekday and weekend rates down and up. The scaling is clamped, so the low rate is never above the expected one and the high rate is never below it.

  This keeps §7's idea (percentiles of spending) and the weekday/weekend shape, but measures over weeks, which aren't lumpy. Steady spending gives a single date. Lumpy spending gives a real range.
- **The rates:**
  - an exponentially weighted average with a 7-day half-life over the 28 days before today, apart for weekdays and weekends (Saturday and Sunday);
  - today is left out, because it isn't over yet and its spending is already in money left;
  - days with no spending count as 0;
  - the window never reaches before the first spending, so a new user's empty past doesn't pull the average down.

  Everything is integer math: fixed-point weights, rounding half up, and `BigInt` for the scaling. No `double` touches money.
- **Cold start:** with fewer than 14 days since the first spending, the rate is the month's overall budget spread evenly over its days, and there is no range. Without a budget there is no forecast, and the card asks the user to keep logging or set a budget.
- **"Include money owed to me"** is a switch on the Home card. It is off by default, because the money may never be paid back, and it lasts for the session. When on, it adds the groups' "owed to me" to the start.
- **Run-out** is the first day the balance goes below 0. A balance of exactly 0 hasn't run out yet. If the balance is already below 0, it has run out today. The horizon is 60 days.

## Consequences

- Before a later month's payday, the forecast can look rosier than the actual cash in hand: money left counts this month's income even if it arrives on the 25th. That's the same view Home already shows.
- The backtest (task 5.3) can replay `ForecastRunOut` directly. It's a pure function of the history, the incomes and money left.
- A `RecurringCost` entity (a synced table, a screen, or detection in v2) plugs in without changing the forecast.
