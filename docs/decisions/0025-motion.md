# ADR 0025: Motion from a few shared widgets, all switched off by one flag

- Status: accepted
- Date: 2026-10-18
- Task: 6.2b, step 5

## Context

Steps 2–4 added some motion (money counting up, Penny's face, poses floating in), each checking `MediaQuery.disableAnimations` on its own. Step 5 adds more motion: number tweens, entrances, haptics and skeleton loaders. All of it has to stop with "reduce motion", and screen readers must get the same information either way.

## Decision

- **One switch: `MediaQuery.disableAnimations`.** Every animated widget reads it. It's on when the phone asks (Android's "Remove animations") or when the app's own **Settings → Reduce motion** is on.
  - `MizanApp` adds the app's switch to the MediaQuery below it, so nothing else needs to know where it came from.
  - It also turns off page transitions and the theme cross-fade.
  - The switch is a per-phone preference in secure storage, next to the theme, read before the first frame.
  - When the phone already asks, the switch shows as on and locked, with a line saying why.
- **Shared widgets in `app/widgets/`:**
  - `Entrance` fades and lifts content in once, staggered by index (the first six only).
  - `AnimatedBar` grows a progress bar to its value; screen readers hear only the final percent.
  - `Skeleton` shows `SkeletonList` and `SkeletonCards` with a sweeping shine, labelled "Loading".
  - `Haptics` has four named moments: `saved`, `deleted`, `settled` and `tick`.
  - `AnimatedMoney` is reused from step 2.
- **Where:**
  - **Home:** the cards come in one after another, the budget bar grows, and the donut sweeps round from the top while its total counts up. The donut uses an empty slice for the part not drawn yet; later data changes use fl_chart's own `duration`.
  - **Budget:** "Money available" counts, the limit bars grow, and the sections come in.
  - **Group balances:** the standing card and members come in.
  - **Skeletons:** they replace the full-screen spinners on Home and Budget (cards), and on Expenses, Income, Categories, Groups, a group's tabs and Settings (list). In-flight buttons and sheets keep their small spinners.
  - **Haptics:**
    - `saved`: saving an expense, income, a limit, a category, a shared expense, or quick-input items.
    - `deleted`: a swipe-delete or deleting an income.
    - `settled`: recording a payment.
    - `tick`: switching tabs or tapping Penny.
- **Haptics are off with reduced motion too.** The task says "everything off", and someone who asks for a calmer phone likely wants fewer buzzes. Otherwise the phone's own vibration settings still apply.
- **Sentences aren't animated.** Amounts inside sentences ("You owe 12.000 DT", "120.000 DT left of …") stay plain text. Counting them would flicker the words and spam screen readers. Only standalone headline figures count.
- No new dependency: `HapticFeedback` is in Flutter's services, and the shine is a `ShaderMask`.

## Consequences

- New screens get motion and its off switch by using these widgets and adding nothing else. A widget that animates by itself must check `disableAnimations` (the tests check that each of these does).
- `test/support/record_haptics.dart` records haptics, so a test can check that a moment is felt and that reduced motion silences it.
- Skeletons shine forever while loading, like the spinners did, so tests of a loading state use `pump`, not `pumpAndSettle`.
- `app/test_shots/skeleton_shots_test.dart` renders the skeletons in both themes for a visual check.
