# ADR 0020: Onboarding for new installs, a saved theme, and accessibility checked in tests

- Status: accepted
- Date: 2026-10-17
- Task: 6.2

## Context

6.2 asks for onboarding (income, budget, optional group), empty states, dark mode, an app icon and accessibility (font scaling, contrast, screen-reader labels). Beta testers already have data, the app has no preferences store, and nothing checked accessibility so far.

## Decision

- **Onboarding shows only on a new install** (decided with the user). `NeedsOnboarding` is true when there's no "onboarded" flag and the phone has no expense, income source or budget. A phone that has any of them (a beta tester updating) skips it and gets the flag, so it never shows later. If storage can't be read, it isn't shown: it must never stand between the user and their data.
- **The router decides.** An async `redirect` sends only `/` to `/welcome`, so an invite link on a fresh install still opens the join screen. Every step can be skipped. Income and budget open the same sheets as the rest of the app, so they go through the same use cases (one transaction + outbox). The group step offers sign-in, or the groups screen when signed in (groups need an account, ADR 0009).
- **Theme: System / Light / Dark in Settings** (decided with the user), saved per phone. `main` reads it before the first frame, so a dark choice doesn't flash light.
- **Per-phone preferences live in secure storage** (`SecureDevicePreferencesRepository`), next to the app lock. Neither value is secret, but this avoids adding `shared_preferences`. They're not in drift because they never sync.
- **Colours with no Material slot** (the chart palette and the "nearly at the limit" amber) are an `AppColors` theme extension with a light and a dark set. A test checks each one has 3:1 contrast on cards and on the page in both themes.
- **Accessibility is a test, not a checklist.** `test/app/accessibility_test.dart` boots the real app (in-memory DB) and visits every main screen, empty and with data, in both themes at 1× and 2× text. It checks Flutter's guidelines (WCAG AA text contrast, 48×48 tap targets, a label on everything tappable) and fails on any overflow. A deliberately low-contrast change fails it. Group screens need an account and aren't covered.
- **Large text stacks instead of squeezing.** A sentence with a button puts the button under it (`TextWithAction`). Title and button rows use `OverflowBar`. At 130%+ text, Home's chart puts its legend below the donut, with each amount under its name (`hasLargeText`).
- **Screen readers:** section titles, day headers and "Money left this month, <amount>" are headings. Swipe-to-delete also has a "Delete" custom action, because TalkBack users can't swipe. Empty and error states share `EmptyState` / `LoadError`, which scroll at large text, and errors are live regions.
- **App icon:** an Android adaptive icon (background, vector foreground, monochrome layer for themed icons), with placeholder art at first. The user's artwork replaced it in ADR 0021. The monochrome layer is also the notification status bar icon (it must be one colour) and FCM's default.

## Consequences

- An install that is restored with an empty database after a reinstall sees onboarding once. It can skip it.
- The test font draws every glyph a full em wide, so the 2× overflow check is stricter than real fonts. That's on purpose.
