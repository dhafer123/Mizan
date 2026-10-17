# ADR 0022: Bottom tabs with their own stacks and snackbars, and a new Home

- Status: accepted
- Date: 2026-10-17
- Task: 6.2b, step 2

## Context

Home reached Expenses, Groups and Budget through small icons in its app bar, and every screen was pushed on one stack. Home showed its numbers as plain text in grey cards, so it worked but didn't look like a finance app.

## Decision

- **Four tabs** (Home, Expenses, Groups, Budget) in a `StatefulShellRoute`. Each tab keeps its own stack and scroll position. Everything else (settings, categories, income, a group, sign-in, onboarding) is a top-level route that opens full screen above the tabs. Back from another tab returns to Home before it leaves the app. Tapping the current tab returns to its first screen.
- **The shell is not a `Scaffold`:** it's a column of the tab body and a `NavigationBar`. An outer Scaffold would show snackbars itself, over the inner screen's add button, which it can't see.
- **Each tab has its own `ScaffoldMessenger`.** All four tabs' Scaffolds stay alive in the indexed stack. With the app's single messenger, one snackbar was shown by every live Scaffold at once, which also crashed on duplicate hero tags.
- **The navigation bar hides while the keyboard is open**, so fields keep their room.
- **The Home hero card** is the brand gradient with white text. The text colours are checked for 4.5:1 across the gradient, and a negative amount uses a light red that stays readable on blue. Money left counts up with `AnimatedMoney`. The tween runs in whole minor units (an `IntTween`), so no doubles touch money, and the amount shows at once with reduced motion.
- **The forecast is a runway**: a bar from today to the next income (or the horizon). It's filled while the money lasts, translucent red after the run-out, with the low–high range shaded and a marker at the run-out. The geometry is a small pure class (`Runway`) with its own tests. The bar is decoration for screen readers, since the headline above says the same.
- **Category colours come from the icon key** (`categoryColor`), so a category has the same colour on every phone with nothing stored or synced. Built-in categories each get their own colour. They're used in the chart, the category avatars and the budget bars.
- **Top categories** puts the donut on top, with the month's total in the hole, and the legend at full width below. Beside the chart, names and amounts were squeezed even at normal text size.
- `app/test_shots/` renders the tabs with the real fonts to PNGs (git-ignored) for a visual check of UI changes. It isn't a test suite and CI doesn't run it.

## Consequences

- Tests that navigated with `pageBack()` from Expenses or Budget now tap the tabs. Tabs keep their scroll position, so a test may need to scroll back.
- A snackbar shown from a top-level screen (Settings, a group) appears only there, as before. One shown from a tab appears only on that tab.
