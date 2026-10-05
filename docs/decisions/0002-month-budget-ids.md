# ADR 0002: Month budgets have ids derived from the month

- Status: accepted
- Date: 2026-10-05
- Tasks: 2.4 (affects 3.3 and 3.4)

## Context

The overall spending limit is set per month and carries forward: a month uses the latest budget set in it or before it. That keeps past months' limits while letting a student set a budget once.

There should be at most one budget per month. If each device gave a new budget row a fresh UUID, two devices setting October's budget offline would sync two October rows. "The budget in force" would then depend on which row won a tiebreak, not on what the user did last.

## Decision

A month's budget id is **derived from the month**: `budget-YYYY-MM` (`Budget.idFor`). Saving a month's budget for the first time on a device queues a `create`; later saves queue an `update` of the changed fields, as usual.

Per-category limits are **not** per month. They are each category's standing `monthlyLimit` (decided with the user for 2.4). The `budget_category_limits` table from 2.1 stays unused, kept for per-month overrides if they are ever needed.

## Consequences

- **Server (3.3 / 3.4):** like categories (ADR 0001), budgets must be keyed by **(owner, id)**. Two devices can both send a `create` for `budget-2026-10`. The server must treat a `create` for an id it already holds as a field-level update of that row (same-field: later wins), not reject it.
- Removing a month's limit stores the row with no limit. It isn't deleted, so "no limit from this month on" carries forward too.
- Changing a category's limit changes what past months show as "left" for that category. The overall limit keeps its history.
