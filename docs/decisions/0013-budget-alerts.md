# ADR 0013: Budget alerts fire once per situation, are logged on the device, and are checked in the background too

- Status: accepted
- Date: 2026-10-07
- Task: 5.2 (ARCHITECTURE.md §4, builds on ADR 0011 and 0012)

## Context

§4 lists three alerts:
- a category has used 80% or more of its limit;
- the forecast runs out before the next income;
- unusual spending, above 2.5× the 4-week median.

TASKS.md adds: local notifications, at most one a day per alert type. Building them raised four questions:

1. The median of what?
2. A cap of one a day still repeats "Food is at 85%" every day until the month ends. Should alerts repeat?
3. Where is "sent" remembered, given that CLAUDE.md rule 3 says every local write goes through the outbox?
4. When are alerts checked, given that the app is often closed?

## Decision

- **Unusual = a single expense** (decided with the user).
  - An expense, or my share of a group expense, dated today or yesterday is compared with the median of its category's expenses in the 28 days before its date.
  - It needs at least 3 of those, and a median above 0.
  - It's unusual when `amount × 2 > median × 5`, in integers.
  - A notification can then say "About 8× your usual 12.000 DT for Food".
- **Once per situation, then at most one a day per type** (decided with the user). Each alert has a *situation*:
  - category limit: the category in that month (once a month);
  - unusual: the expense (once);
  - run-out: the payday it warns about. It fires again before that payday only if the run-out date moves earlier than every warning so far. With no income scheduled, the situation is "no income".

  `SelectAlertsToSend` drops situations already sent, skips any type already sent today, and sends the most pressing alert of each remaining type: the category with the highest share used, the expense furthest above its usual cost, or the earliest run-out.
- **Pure core, thin shell.**
  - `ComputeBudgetAlerts` (what holds now) and `SelectAlertsToSend` (what to send) are pure.
  - `SendBudgetAlerts` reads the log, shows each alert through `AlertNotifier`, and logs it only once shown. If notifications are off, nothing is logged, so the alert is tried again later.
  - Checks run one at a time per isolate, so quick successive changes can't send the same alert twice.
- **The log is local only** (`sent_alerts`, schema v7).
  - It has no sync columns and no outbox. Notifications belong to a phone, and syncing "sent" would stop your other phone from ever warning you. Rule 3 is about synced data, and this table isn't synced.
  - Rows older than 92 days are pruned, because nothing reads back more than 62.
  - Signing in to another account wipes the log along with the synced data.
- **Checked in the app and in the background** (decided with the user).
  - `AlertsLifecycle` asks for notification permission once. It sends alerts whenever their inputs change (every write and every pull feeds the same providers as Home), and checks again on resume, in case the day changed.
  - The WorkManager task (ADR 0011, about every 15 minutes while signed in) runs the same check after its sync. Run-out warnings and roommates' expenses then notify you even with the app closed.
  - Alerts never include money owed to me in the forecast.
- **One notifications setup.** The plugin is a singleton, and a second `initialize` replaces the first tap handler. So `LocalNotifications` initializes it once and hands taps out by payload:
  - budget alerts use payloads starting with `local:`, and push ignores those;
  - alerts use their own Android channel, "Budget alerts", so users can turn them off apart from group notifications;
  - each alert type has one notification id, so a newer alert of that type replaces the older one.

## Consequences

- The app and the background isolate each serialize their own checks, but not against each other. If both run at the same moment, one alert can show twice. That's rare, and harmless.
- Background checks only run while signed in, because that's when WorkManager is scheduled.
- Unusual spending reads this and last month's expenses, so early in March its 4-week window can be a day or two short.
