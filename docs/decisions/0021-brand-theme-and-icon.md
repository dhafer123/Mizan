# ADR 0021: Brand colours set by hand, a bundled font, and the icon redrawn as vectors

- Status: accepted
- Date: 2026-10-17
- Task: 6.2b, step 1

## Context

The app used Material colours generated from a teal seed, so it looked like a template. The user supplied the brand: an app icon (`docs/brand/icon.png`) and a mascot sheet (`docs/brand/mascot-sheet.png`) in navy, royal blue, cyan, soft white and amber.

## Decision

- **Colour schemes are written out by hand** (`AppTheme.lightScheme` / `darkScheme`), not generated from a seed. A seed turns royal blue into lavender. It also can't know that cyan fails as text on white (about 1.8:1).
  - **Light:** royal blue `#2D4BD8` leads. Cyan appears only as fills, and in the chart, deepened to `#00869E`. Amber is the tertiary colour and the warning colour.
  - **Dark:** navy surfaces (`#0B1026` up to `#252E55`) and cyan `#22D3EE` as primary, like the icon's glow. Royal blue becomes the primary container.
- **Every text pair is tested.** `app_theme_test.dart` checks 4.5:1 for each on-colour against its colour, and for text against every surface level, in both themes. It also checks 3:1 for chart and warning colours. The screen-level accessibility test (ADR 0020) covers real screens.
- **Font: Manrope**, rounded and geometric like the mascot. It's bundled as five static weights (400–800, about 490 KB) cut from the Google Fonts variable font with fontTools, under the SIL Open Font License (`app/assets/fonts/OFL.txt`). There's no `google_fonts` package and no download at runtime: the app is offline-first.
- **The icon is redrawn, not cropped.** The artwork is one flat image with a squircle and a dark border baked in, but Android adaptive icons need separate layers and launchers apply their own shape.
  - `app/tool/icon/make_icon.py` holds the M, bars and wallet as polygons in the artwork's pixels.
  - It writes three vector layers: the navy-gradient background with waves, the foreground, and a monochrome layer for themed icons and the notification icon.
  - It also renders a preview next to the artwork.
  - The legacy Android 7 PNGs and a 512 px store icon are cut from the artwork itself.
- The window and launch screen use each theme's page colour, so opening in dark mode doesn't flash white.

## Consequences

- Changing a colour means editing the scheme and passing the contrast test. That's on purpose.
- Changing the icon means editing the polygons in the script and running it again. The XML files are generated.
- Widget tests still render the test font. Only the theme test checks that Manrope is set.
