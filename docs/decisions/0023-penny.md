# ADR 0023: Penny, the mascot: a code-drawn head, moods from the domain, lines that keep the facts

- Status: accepted
- Date: 2026-10-17
- Task: 6.2b, step 3

## Context

The user wanted a mascot (named Penny) to make the app feel alive: expressions that follow the money, and silly lines in some situations. A finance app has to stay trustworthy, so a joke must never hide or replace the numbers.

## Decision

- **A new `mascot` feature.** Penny reacts to budget, forecast and sync data, so she belongs to none of those features.
- **Her mood comes from the domain.** `ReadPenny` is pure and fully tested, with a property test for its rules. It turns the same facts as the budget alerts (`ComputeBudgetAlerts`), the forecast and the sync phase into a `PennyState`: a `PennyMood` plus a `PennyReason` carrying the facts. The most pressing reason wins:
  1. running out before payday;
  2. over a limit;
  3. an unusually big expense;
  4. near a limit;
  5. offline;
  6. no income;
  7. a quiet month;
  8. still learning;
  9. on track.
- **Reactions are the presentation's.** Something just done (an expense saved from Home, setup finished) shows for 5 seconds (`PennyReaction`), then her Home mood comes back. The first expense of the month gets a bigger cheer.
- **Her head is drawn in code** (`PennyPainter`, on a 100×100 canvas) from the mascot sheet, so she has 8 expressions at any size with no assets and no dependency. She's alive in short bursts on timers, not endless loops: a blink or bob every few seconds, a pulse while listening, floating z's while asleep, a bounce on a mood change or a tap. The screen settles in between, which keeps `pumpAndSettle` tests working and saves battery. With reduced motion she holds still.
- **Her lines are in one file** (`PennyLines`): silly and never shaming, a few per reason. The same line shows all day, and tapping her picks another. Each line must contain its reason's facts (date, amount, category, percent), and `penny_lines_test.dart` checks every line. It caught two that had dropped theirs.
- **She's decoration for screen readers.** The head is excluded; the bubble reads "Penny says: …". If her mood can't be worked out she isn't shown at all, so she never blocks Home.
- Where she appears: the top of Home, and voice input (her listening face, bouncing as words arrive). Full-body poses for onboarding and empty states come in step 4 (`docs/brand/penny/`).

## Consequences

- New moods or reasons mean a `ReadPenny` rule plus a test, a face in `PennyPainter`, and lines that pass the facts test.
- The sync phase affects her mood (sleepy when offline) but never a money warning: those always come first.
