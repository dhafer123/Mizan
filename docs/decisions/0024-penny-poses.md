# ADR 0024: Penny's full-body poses as processed WebP assets, with her face as the fallback

- Status: accepted
- Date: 2026-10-17
- Task: 6.2b, step 4

## Context

The user made Penny's full-body poses with an image generator. They're 1254 px PNGs on flat magenta, about 1.4 MB each, with slightly different framing. The app needed them for onboarding and empty states, in both themes.

## Decision

- **The originals stay in `docs/brand/penny/`.** `app/tool/penny/make_poses.py` turns them into app assets in `app/assets/penny/`:
  - it removes the magenta and de-tints the pink edges;
  - it trims each pose and scales it to the same character height (wide poses fit the width instead);
  - it puts the feet on one line on a 600 px square;
  - it saves WebP with transparency.

  The nine together come to about 320 KB. Rerun the script when a pose is added or changed.
- **`PennyArt` lists the poses**, each with the face (`PennyMood`) that's drawn instead if its artwork can't load, so a pose can never break a screen.
- **`PennyPose` shows one:** decoded at the size shown (`cacheWidth`), on a soft glow in the theme's primary colour, floating in gently (not with reduced motion). It's decoration for screen readers: the text beside it says what it means.
- **Where they appear:**
  - **Onboarding:** wave (welcome), wallet (income), budget, and friends (groups). The welcome now introduces Penny.
  - **Empty states:** Expenses (phone), Income (wallet), Groups (friends), a group's expenses (phone) and history (sleep).
  - **Every load error:** worried.
  - **Settle up:** celebrate, when a group is settled after spending together.
  - **Voice input:** listen (added 2026-10-18), hopping a little as words come in. It replaces her drawn head there.
- `EmptyState` takes a pose or an icon.

## Consequences

- Adding a pose means dropping `penny_<name>.png` in `docs/brand/penny/`, rerunning the script, and adding it to `PennyArt`. A pose with props spread wide (listen's coins) is fitted to the width, so she comes out a little smaller than in the others.
- Image generators drift, so a new pose should be checked next to the others (`app/test_shots/` renders them in place) before it ships.
