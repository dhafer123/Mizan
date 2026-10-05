# ADR 0003: App lock in secure storage; CSV export through the system file picker

- Status: accepted
- Date: 2026-10-05
- Task: 2.6

## Context

Task 2.6 adds a PIN or biometric lock and a CSV export of expenses. The user approved `local_auth` and `flutter_secure_storage`. They did not approve `crypto` (to hash the PIN) or `share_plus` / `path_provider` (to share a file).

## Decision

**Lock**
- The lock is a 4 to 6 digit PIN. A fingerprint or face can also unlock it, but only if the user turns that on. Turning it on needs one successful check. `local_auth` runs with `biometricOnly`, so the fallback is the app's PIN, not the phone's.
- Lock settings are kept per device in `flutter_secure_storage` (on Android, encrypted with a Keystore key). They are not in drift and are never synced, so they don't go through the outbox.
- The PIN is stored as it is, not hashed, because `crypto` was not approved. The Keystore encryption protects it at rest; a rooted phone could read it.
- The app locks at a cold start, and again when it comes back after `ShouldLockOnResume.after` (1 minute) or more in the background. The time away is counted from the first `hidden`/`paused` and checked on `resumed`. `inactive` doesn't count, so the biometric prompt itself never counts as time away. If the clock went backwards, the app locks.
- After 5 wrong PINs in a row, every try is refused for 30 seconds. The count is in memory, so restarting the app resets it.
- `AppLockGate` wraps the app in `MaterialApp.builder`. While locked, the app stays mounted (offstage, tickers off), so unlocking returns to the same screen.
- If secure storage can't be read, the app opens. The PIN couldn't be checked anyway, so locking would shut the user out of their own data.

**Export**
- `BuildExpensesCsv` writes RFC 4180 CSV:
  - comma-separated with CRLF line endings, in UTF-8 with a byte-order mark;
  - dates as `YYYY-MM-DD`, amounts as dot decimals, the currency in its own column;
  - cells that start with `=`, `+`, `-` or `@` get a `'` prefix, so a spreadsheet doesn't run them as formulas.
- `MainActivity` opens Android's "save as" picker (`ACTION_CREATE_DOCUMENT`) over the `mizan/file_export` channel and writes the bytes there. This needs no storage permission and no new package.

## Consequences

- `MainActivity` is a `FlutterFragmentActivity`. `minSdk` is 24, which both plugins require. `USE_BIOMETRIC` is declared.
- The launch theme is not AppCompat. `local_auth` warns this can crash the biometric prompt on Android 8 and below (API 24–27). If that matters, the fix is AppCompat as an Android dependency.
- The CSV opens correctly in Excel when its list separator is `,` (checked: 7 columns, numbers that add up). A semicolon locale, such as French Excel, needs Data › From Text instead. Google Sheets and LibreOffice ask on import.
- Recent apps still shows a thumbnail of the app. Hiding it (`FLAG_SECURE`) would also block screenshots, so it is left out for now.
- If `crypto` is approved later, store a salted PBKDF2 hash instead of the PIN. Only `SecureLockSettingsRepository` and `UnlockWithPin` change.
