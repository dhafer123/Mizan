# TASKS.md — Mizan

One task = one Claude Code session = one commit (or a small PR).
Prompt: **"Do task X.Y from TASKS.md. Read the ARCHITECTURE.md sections it references, plan first, then implement with tests, then run analyze and tests."**
Don't tick a box until its *Done when* is true. Each week ends with a **Gate**; don't start the next week until it passes.

Plan: 6 weeks, Oct 6 – Nov 16, 2026. Beta with classmates from week 5.

---

## Week 1 (Oct 6–12): foundations and the domain core

The money and group logic is built and proven first, with no UI, because everything else depends on it.

- [x] **1.1 Monorepo + app skeleton** (§3)
  `app/` (Flutter), `server/` (empty for now), `docs/`. Feature folders per §3, Riverpod, go_router, freezed, lints, README stub.
  *Done when:* the app runs and shows a placeholder home screen; analyze and test pass.

- [x] **1.2 CI**
  GitHub Actions: `flutter analyze`, `flutter test --coverage`. Add a check that fails if any file under `*/domain/` imports flutter, drift, dio or a plugin.
  *Done when:* CI is green, and the import check fails on a deliberately bad import.

- [x] **1.3 Core: Money, Result, Clock, IDs** (§4)
  `Money` (int minor units, currency, add/subtract/compare, parse and format at the edge), `Result<T, Failure>`, a `Clock` interface with a fake, and a UUIDv7 generator.
  *Done when:* unit tests cover parsing "4.5", "4,500" and "4.500 DT" → 4500, negative values and currency mismatches.

- [x] **1.4 Splits** (§4)
  `computeShares` for equal, exact, percentage and shares (weights), plus subsets of members. Largest-remainder rounding by member id.
  *Done when:* property tests (glados) show shares always sum to the amount, and are deterministic for the same input.

- [x] **1.5 Balances** (§4)
  `computeBalances(expenses, settlements)`, including reversing settlements.
  *Done when:* the property test "balances sum to 0" passes, and the worked example (rent 900 / groceries 120 / internet 60 / trip 300 → +540 / −90 / −450) is a named test.

- [x] **1.6 Debt simplification** (§4)
  Greedy `simplifyDebts`.
  *Done when:* property tests show at most n − 1 transfers and that applying them zeroes every balance; the worked example gives 2 transfers (Sami → you 450, Ali → you 90).

**Gate 1:** domain coverage ≥ 90%, all invariants proven by property tests, CI green.

---

## Week 2 (Oct 13–19): the personal app, offline only

- [x] **2.1 drift schema + outbox** (§5)
  Tables for expenses, categories, income sources, budgets, outbox, sync_state and entity_history. Sync metadata columns on synced tables. Migrations set up.
  *Done when:* DAO tests on an in-memory DB pass, including a test that an entity write and its outbox append happen in one transaction (a forced failure leaves neither).

- [x] **2.2 Expenses feature** (domain → data → presentation)
  Use cases: add, edit, delete (tombstone), list by month. Screens: add/edit sheet, expense list grouped by day, swipe to delete with undo.
  *Done when:* the full flow works offline, and widget tests cover the add sheet, including validation errors.

- [x] **2.3 Categories**
  Default student categories (food, transport, rent, study, leisure, other), plus custom ones with an icon and an optional monthly limit.
  *Done when:* you can create, rename and archive categories, and archived ones keep their history.

- [x] **2.4 Income + budget**
  Income sources (monthly on day N, one-off, irregular), monthly budget overall and per category, and a "money available" calculation.
  *Done when:* the use case tests pass, and the budget screen shows used / left per category.

- [x] **2.5 Home dashboard**
  Money left this month, days until next income, top categories (fl_chart), recent expenses.
  *Done when:* all states (empty month, normal, over budget) are covered by widget tests.
  *Note:* added fl_chart (approved). "Money left" is income − spending (same as the Budget screen); top 4 categories get a slice, the rest are summed; recent = newest 5 from this and last month, so it isn't empty on the 1st. Home's Expenses/Budget buttons moved to the app bar.

- [x] **2.6 Settings: app lock + CSV export**
  PIN or biometric lock (`local_auth`), and CSV export of expenses.
  *Done when:* the lock appears on resume after 1 minute in the background, and the exported CSV opens correctly in a spreadsheet.
  *Note:* PIN (4-6 digits) + optional biometrics; PIN kept in secure storage, not hashed (`crypto` not approved). Export via the Android "save as" picker over a platform channel (no share_plus). minSdk 24, FlutterFragmentActivity. See ADR 0003.

**Gate 2:** you can use the app daily for personal expenses, fully offline. Start logging your own spending now: it becomes forecast test data.

---

## Week 3 (Oct 20–26): server, auth and sync

- [x] **3.1 Django project + Docker** (§9)
  Apps `accounts`, `ledger`, `sync`, `groups`, `notifications`. Postgres in Docker Compose, pytest-django, and server tests in CI.
  *Done when:* `docker compose up` runs, and an empty pytest suite is green in CI.
  *Note:* Django 6.1 / DRF 3.18 / psycopg 3 on Python 3.12, Postgres 18. Custom `accounts.User` created now (before the first migration) so 3.2 can switch to email login. API-only (no admin/sessions); DRF is JSON-only and `IsAuthenticated` by default. `GET /health` checks the DB. CI's `compose` job runs `docker compose up --wait` and curls `/health`. Verified: run 37441649129 (test + compose green).

- [x] **3.2 Auth**
  Email + password sign-up and login, simplejwt access and refresh tokens, and a devices table. App side: login and sign-up screens, a dio interceptor for refresh, tokens in secure storage. The app stays usable offline before the first login (local-only mode).
  *Done when:* there are server tests for auth, and app tests for token refresh with a mocked dio.
  *Note:* Added simplejwt + dio (approved); no mocktail — refresh is tested through a scripted dio `HttpClientAdapter`. Refresh tokens rotate and work once; on a rejected refresh the app signs out locally, offline keeps the session. Sign-in lives in Settings → Account; logout keeps local data. API URL: `--dart-define=MIZAN_API_URL` (default emulator host). See ADR 0004.

- [x] **3.3 Server ledger models + `server_seq`** (§6)
  Mirror the synced entities with `version`, `deleted`, `updated_by` and `server_seq` (from a Postgres sequence, set on every write). Add the applied-op log and the history table.
  *Done when:* migration and model tests pass, and `server_seq` is strictly increasing across writes.
  *Note:* Mirrors expenses, categories, income sources, budgets, plus groups, members, shared expenses and settlements (3.4's conflict tests need membership and insert-only settlements; invites stay in 4.1). Triggers set `version` and `server_seq` on every write; seqs are taken under an advisory lock so commit order = seq order. Settlements, history and the applied-op log are insert-only in the DB. See ADR 0005.

- [x] **3.4 `/sync/push`** (§6)
  Idempotency by `opId`, permission checks, `baseVersion` check, and the full conflict policy table (field merge, same-field later wins, delete wins, insert-only settlements). Results per op.
  *Done when:* there's one pytest per row of the conflict table, plus idempotency and permission tests.
  *Note:* Push takes `{deviceId, ops}`; "concurrent" = changed by another device since `baseVersion` (a device's own queued ops share a base until it pulls). Each op runs under the ledger lock with its applied-op record in the same transaction. Edits after a delete are rejected `deleted` and kept in history as `discarded`; a create on a tombstone restores. Entities: the 4 personal ones + shared expenses and settlements (groups/members via push in 4.1). See ADR 0006.

- [x] **3.5 `/sync/pull`** (§6)
  Changes since the cursor, scoped to the user's records and groups, including tombstones, paginated.
  *Done when:* tests cover scope (no data leaks from other users) and pagination boundaries.
  *Note:* `{changes: [{entity, serverSeq, state}], cursor, hasMore}`, limit 200 (max 500). Each page is one REPEATABLE READ snapshot, so no gaps (tested with a mid-page commit). History rows come in the same stream as `entity_history`, with a `kind` the app table doesn't have yet (3.6). Groups and members are pulled but not pushable until 4.1.

- [x] **3.6 Sync client** (§6)
  Outbox processor (batches, exponential backoff), pull + apply + rebase of pending ops, cursor storage, and triggers (start, reconnect, debounced write, WorkManager). A sync status indicator in the UI.
  *Done when:* an integration test does airplane mode → 5 edits → online, and the server has all 5.
  *Note:* Added connectivity_plus + workmanager (approved). The proof is `app/test_e2e/` against a real Django server (CI job `e2e`), not an on-device integration_test. Account switch = wipe and pull (decided with the user); first sign-in uploads local-only data. Schema v2 (`sync_state.account_id`, `entity_history.kind`, `outbox.reject_reason`). See ADR 0007.

- [x] **3.7 Sync simulation harness** (§11)
  2–3 fake clients plus an in-memory fake server that follows the same rules. Random ops, random offline periods, random push/pull order.
  *Done when:* 1,000 random scenarios per CI run all satisfy the 4 invariants (convergence, no lost writes, money integrity, idempotency).
  *Note:* The clients run the app's real sync stack (drift, repositories, use cases); only time and the network are fake, with lost push responses. Same scenarios also run against the real Django server (50 in the `e2e` job). Found and fixed 4 bugs: pulled nulls not clearing, rejected edits stuck on tombstones, stale values after a lost-response replay (→ shadow rows, schema v3), and DB connection exhaustion (`CONN_MAX_AGE`). Money integrity on devices covers personal data; group balances are checked on the server (decided with the user). See ADR 0008.

**Gate 3:** the same account on 2 devices (or emulator + phone) converges after conflicting offline edits, and the simulation is green.

---

## Week 4 (Oct 27 – Nov 2): shared expenses

- [x] **4.1 Groups + members + invites** (§4, §9)
  Create a group (name, currency), invite by link or QR (expiring token), join, and add placeholder members that a real user can claim later.
  *Done when:* server tests cover invites (valid, expired, reused) and claiming; you can join a group from a second device.
  *Note:* Groups and members sync through push (founder rule: only the creator's own first member row may set `userId`). Invites are server-only, single-use, 7 days; an invite can target a placeholder to claim it. Joining triggers a group-scoped backfill (`/sync/pull?group=`). Added qr_flutter (approved); the QR holds a `mizan://mizan.app/join/<token>` link, scanned with the phone's camera or pasted (no in-app scanner). Schema v4 builds groups/members from shadows. Second-device join proven by `test_e2e/join_group_e2e_test.dart` on a real server. See ADR 0009.

- [x] **4.2 Add shared expense**
  Payer, amount, split type (equal / exact / % / shares), member subset, category. A live preview of each share; the save button is disabled until the shares sum to the amount.
  *Done when:* widget tests cover each split type, and the server rejects a share sum mismatch.
  *Note:* The server now also recomputes the shares from the split (same largest-remainder rule) and rejects `split_mismatch` / `invalid_split`; split JSON is fixed in ADR 0010. Schema v5 adds `shared_expenses`, built from shadows. Expenses are dated today (no date picker yet) and can't be edited or deleted yet. The simulation now adds shared expenses on phones and checks group balances sum to 0 on every phone. See ADR 0010.

- [x] **4.3 Group detail: balances + history**
  Balance per member, "you owe / you're owed", an expense list, and edit history ("Ali changed amount 120 → 150").
  *Done when:* the balances match the domain tests for the same data.
  *Note:* Group screen has Balances / Expenses / History tabs. Balances are recomputed from rows on every change (`WatchGroupBalances` → `ComputeBalances`, never stored); `test/features/groups/data/group_balances_test.dart` stores the domain worked example through the real DB and use cases and gets +540 / −90 / −450. History is the pulled server history (only accepted changes; lost and discarded edits included), matched to the group by entity id since history rows carry no group, last 300 shown. Settlements join the balances in 4.4.

- [x] **4.4 Settle up**
  Suggested transfers from `simplifyDebts`, a "record payment" action, and a reversing settlement for mistakes.
  *Done when:* recording all the suggested payments brings every balance to 0 on both devices.
  *Note:* "Settle up" tab: suggested payments (each "Record", amount editable for partial payments), any other payment, and the payment list with "Undo" (a reversing settlement; a payment is undone once, a reversal can't be undone). Schema v6 adds `settlements` (from shadows); balances now come from expenses + settlements. Proven by `test_e2e/join_group_e2e_test.dart` on a real server (all balances 0 on both phones). Sync fix: a create the server refuses and never stored (e.g. two phones undoing the same payment offline → `already_reversed`) is now removed locally; the simulation (now recording/undoing payments on phones) failed without it. See ADR 0008 addendum.

- [x] **4.5 Personal budget integration** (§4)
  Only **my share** counts as spending. What others owe me is shown separately.
  *Done when:* a test shows that paying 900 rent for 3 adds 300 to my spending and 600 to "owed to me".
  *Note:* `WatchMyGroupMoney` gives my share of every shared expense (spending, in the expense's category; none → "Other") plus "owed to me" / "I owe" from current group balances (all-time, not monthly). Budget overview, money available and the dashboard add the shares; owed/owe show apart on Home and Budget and never change money left. Groups in another currency than the app's are left out. Test: `test/features/groups/domain/usecases/watch_my_group_money_test.dart`.

- [ ] **4.6 Push notifications (FCM)**
  New shared expense, added to a group, and a weekly settle-up reminder. A "data changed" push triggers a sync.
  *Done when:* an expense added on device A appears on device B within seconds while B is online.
  *Note:* Code done and Firebase set up (project `mizan-bc92e`; the key is valid for FCM). Checked on one real phone (Galaxy A16 over LAN): sign-in, sync, creating a group and the QR invite work. **Still to do: the two-person, two-phone check** (Done when + Gate 4). Run it with `--dart-define=MIZAN_API_URL=http://<PC LAN IP>:8000` and `FCM_CREDENTIALS_FILE` set in the server's shell. Compose now passes `FCM_CREDENTIALS_FILE`, and `.dockerignore` keeps the key out of the image. A push is only a "sync now" signal, never data. Server (`notifications/`): FCM HTTP v1 via google-auth + requests, sent after commit on a background thread. It notifies other members of a new shared expense or someone joining (joining by invite is the only way into a group), sends data pushes to members' and my other phones, runs weekly reminders (`manage.py send_settle_up_reminders`, cron) for whoever owes, and clears dead tokens. App: `PushListener` registers the token (`PUT /auth/devices/<id>/push-token`), syncs on every push, shows notifications while open and opens the group on tap. No background handler (it would sync in a second isolate). Firebase is optional: without config push is off and the APK still builds. connectivity_plus pinned to 7.3.1 (dbus conflict with flutter_local_notifications 22). See ADR 0011.

**Gate 4:** two real people share a group on two phones, with offline edits, and all balances match.

---

## Week 5 (Nov 3–9): smart warnings and fast input

- [x] **5.1 Forecast** (§7)
  Weighted daily spend split into weekday and weekend, a day-by-day projection with incomes and recurring costs, a low–high range, cold-start mode, and an optional "include money owed to me".
  *Done when:* unit tests use fixed synthetic histories (steady, weekend-heavy, irregular income, cold start).
  *Note:* `EstimateDailySpend` + `ForecastRunOut` (pure, integer-only). Starts from Home's money left and adds only later months' income (decided with the user). The range scales the rates by the 25th/75th percentile of 7-day totals, not daily ones (mostly 0 for students). `RecurringCost` is an input only: the app passes none until there's an entity (decided with the user). Home gets a forecast card with a session-long "count money owed to me" switch. Tests: `test/features/budget/domain/usecases/{estimate_daily_spend,forecast_run_out}_test.dart` (named histories plus properties: earliest ≤ expected ≤ latest, more money never runs out sooner, constant spend gives that rate). See ADR 0012.

- [x] **5.2 Alerts** (§4)
  Category ≥ 80% used, run-out before next income, unusual spending (> 2.5× the 4-week median). Local notifications, at most one a day per alert type.
  *Done when:* use case tests cover each alert's trigger and its cooldown.
  *Note:* Decided with the user: "unusual" is a single expense against its category's median; each alert also fires once per situation (category per month, expense once, run-out again only if earlier); checked in the app on every change and after each background sync. `ComputeBudgetAlerts` / `SelectAlertsToSend` are pure; `SendBudgetAlerts` logs only what was shown. Local-only `sent_alerts` table (schema v7, no outbox: notifications are per phone). Push and alerts now share one `LocalNotifications` (the plugin is a singleton); alerts have their own Android channel. See ADR 0013.

- [ ] **5.3 Forecast backtest**
  A script (in Dart or the notebook) that replays a history day by day and computes the mean absolute error in days.
  *Done when:* the error on your own 4+ weeks of data is in METRICS.md.
  *Note:* Tool built, **not ticked: needs the real run.** `dart run tool/forecast_backtest.dart <export.csv> --income AMOUNT:WHEN --budget AMOUNT --end <export day>` (from `app/`). Replays at the end of each day with data up to that day; the actual date comes from `ForecastRunOut.runOutDay` (pulled out of the forecast) spending the real amounts, so both sides count money the same way. Days the data can't settle are lower bounds or censored, and reported apart (ADR 0014). Tests: `test/tool/backtest/`.                                                              
- [x] **5.4 Quick input: rule parser** (§8)
  "coffee 3.5 and taxi 8", "3.5 café w 8 taxi", amounts with "," or ".", in FR / EN / Darija-in-Latin-letters. Returns items with a confidence score.
  *Done when:* there's a table-driven test of 50+ phrases, and the rule-only accuracy is in METRICS.md.
  *Note:* `ParseExpenseText` (pure) → items (label, `Money`, confidence 0–100); below `fallbackBelow` (60) the LLM tier (5.5) takes over. Decided with the user: in TND a bare whole number ≥ 1000 is millimes ("kaskrout 3500" = 3.500 DT). `ExpenseKeywords` (FR/EN/Darija → default category) raises confidence now and is the categorizer's rules tier in 5.7. Numbers in words, dates and quantities are left to the LLM. Test: `test/features/quick_input/domain/usecases/parse_expense_text_test.dart` (61 phrases, 8 marked hard, plus a round-trip property test). See ADR 0015.

- [x] **5.5 Quick input: voice + LLM fallback** (§8)
  `SpeechRecognizer` interface with a speech_to_text implementation. The LLM fallback (flutter_gemma) returns JSON validated against a schema. A confirmation sheet shows the result.
  *Done when:* accuracy (rules vs rules + LLM) on a held-out set of 30 phrases you wrote yourself, and the median time from end of speech to the confirmation sheet, are in METRICS.md.
  *Note:* Ticked by the user's call after the phone check (2026-10-08): speech works; median 5.5 s from end of speech to items (8 phrases, release, Galaxy A16). **Held-out accuracy (rules vs rules + LLM) not measured**: the 30 phrases are in `integration_test/held_out_phrases.dart`, run `quick_input_eval_test.dart` when wanted. Seen on the phone: English is read well; French/Darija less so, mostly because the recognizer follows the phone's language (en-US). A speech-language setting is in v2. Decided with the user: flutter_gemma **0.12.6** (newer needs Flutter ≥ 3.44, or sqlite3 3.x against drift's 2.9.4 pin), **Qwen2.5 0.5B** `.task` downloaded from HuggingFace (Apache-2.0, not gated, ~547 MB, opt-in in Settings), speech_to_text **7.4.0**; integration_test added (SDK). `ParseQuickInput`: rules first, LLM below 60, JSON checked by `ReadLlmAnswer` (labels must come from the phrase), and rules again on a failure or a 20 s timeout. Mic on Home → listening sheet (or typing) → confirmation sheet (edit, remove, category from keywords) → `AddExpenses` (all or none, one transaction). The arm64 APK grows ~24 → ~88 MB (MediaPipe natives; unused engines excluded). See ADR 0016.

- [x] **5.6 Quick input: receipt**
  ML Kit OCR → total and date extractor → LLM fallback → confirmation sheet.
  *Done when:* total accuracy on 30+ real receipts is in METRICS.md.
  *Note:* Ticked by the user's call (2026-10-08) after a phone smoke run; **total accuracy on 30+ real receipts not measured** (eval ready, see below). Decided with the user: google_mlkit_text_recognition **0.16.0** (Latin, bundled) and image_picker **1.2.3** (system camera, no camera permission); the newest that fit Flutter 3.38. `GroupReceiptRows` rebuilds printed rows from OCR boxes. `ExtractReceipt` finds the total by name (NET A PAYER > TOTAL TTC > TOTAL…), skipping subtotal/TVA/cash/change rows, plus the date and the shop. No named total → largest amount at 40 → LLM, whose total must be printed on the receipt. One receipt = one expense (shop as note, receipt's date, source `receipt`). Entry: Scan receipt / From photos in the quick input sheet. arm64 APK ~88 → ~100 MB. Smoke run on the Galaxy A16 (2026-10-08, 6 stock template receipts in USD, answer key read off the images, *not* for METRICS): rules only 4/6, median OCR + rules 358 ms; the 2 misses led to fixes (a subtotal is the fallback total when nothing names one; a currency symbol before a whole number counts as a unit). `flutter test` on a phone uninstalls the app and wipes its local data and the model. To finish: photos + `truth.csv` in `receipts_eval/` (git-ignored), then `flutter test integration_test/receipt_eval_test.dart` and copy them in with `run-as` when it waits (steps in the test's header). See ADR 0017.

- [ ] **5.7 Categorizer** (§8)
  User memory (learned from corrections) → rules → LLM.
  *Done when:* there's a test that one correction changes future suggestions for the same merchant, and categorization accuracy is in METRICS.md.

- [ ] **5.8 Beta release to classmates**
  Distribute through Play Store internal testing (or APK). Add a simple in-app feedback button and an opt-in, anonymous usage counter (expenses logged per day, input method used).
  *Done when:* 10+ students have it installed.

**Gate 5:** the forecast error and input accuracy are measured, and the beta is live.

---

## Week 6 (Nov 10–16): polish, evaluate, ship

- [ ] **6.1 Fix beta feedback**
  Triage into must / should / later, and fix every "must".
- [ ] **6.2 UX polish**
  Onboarding (income, budget, optional group), empty states, dark mode, app icon, and accessibility (font scaling, contrast, screen-reader labels).
- [ ] **6.3 Performance**
  Cold start time, list scrolling with 2,000 expenses, and sync time for 500 ops. Record them in METRICS.md and fix anything slow.
- [ ] **6.4 Account deletion + privacy note**
  Delete server data, keep a local copy if the user wants, and a short privacy page.
- [ ] **6.5 ADRs**
  The 6 decisions in ARCHITECTURE.md §12, each in about half a page.
- [ ] **6.6 README**
  GIF, feature list, architecture diagram, sync explanation, metrics table, how to run (app + server), and the test strategy.
- [ ] **6.7 Demo video** (90 s)
  Voice entry → forecast warning → shared rent with a roommate → airplane-mode edit → sync → settle up.
- [ ] **6.8 Release + CV**
  Play Store closed or open testing, GitHub release, and the CV line with real numbers.

**Gate 6:** released, the README has real metrics, and the demo video is published.

---

## Later (v2) — don't start before Gate 6

- Bank SMS / notification suggestions (Android)
- Savings goals
- Automatic detection of recurring expenses
- Monthly insights report
- Multi-currency for students abroad
- Whisper on-device speech recognition
- Speech language setting for quick input (French / English / Arabic-Tunisia); the recognizer follows the phone's language today (seen in 5.5)

## Notes

<!-- One dated line per decision that changed the plan, e.g. "2026-10-22: pull pagination size 500 → 200, timeouts on slow 3G." -->
- 2026-10-05: 1.1 — Riverpod stack resolves to flutter_riverpod 3.1 / riverpod_generator 4.0.0+1 on Dart 3.10.8 (newer generator needs Dart ≥ 3.12). Generated `*.g.dart` / `*.freezed.dart` are gitignored; CI must run build_runner.
- 2026-10-05: 1.2 — Import check is an allowlist (pure-Dart packages only) and also covers `core/`, since domain builds on it. CI runs on push to any branch (no `gh` CLI for PR-only triggers). Verified: run 37301640329 failed on a deliberate flutter import in domain/.
- 2026-10-05: 1.3 — Mixing currencies in `Money` arithmetic throws `CurrencyMismatchError` (a bug, not a user error); wrong-currency *input* is a `MoneyParseFailure`. Parser: a lone "." or "," is the decimal point ("4,500" = 4.500 DT), except "1,234" for 2-decimal currencies. `FakeClock` lives in `lib/core/clock/` so integration tests can use it. CI also enforces domain + core line coverage ≥ 90% (`tool/check_coverage.dart`).
- 2026-10-05: 1.4 — `Split` is a freezed union (equal / exact / percentage / shares); the participants are the subset. Percentages are integer basis points (33.33% = 3333, must total 10000), so no doubles. Amount must be > 0; zero-weight members stay in the result with a 0 share. Rounding: largest remainder first, then lowest member id; `BigInt` for amount × weight.
- 2026-10-05: 1.5 — `SharedExpense` stores the `Split` *and* the computed `shares` (rounding changes can't move old balances). A reversing settlement mirrors the original (from/to swapped, `reversesId` set), so balances need no special case. `ComputeBalances` returns a `Result` and rejects rows that would break the zero sum. Sync metadata (`version`, `deleted`, …) is deferred to 2.1/3.3; callers pass live rows only.
- 2026-10-05: 1.6 — `SimplifyDebts` returns `Result<List<Transfer>, SimplifyFailure>` (rejects unbalanced or mixed-currency input). Greedy with ties to the lowest member id, so every device suggests the same transfers. Gate 1 numbers recorded in METRICS.md.
- 2026-10-05: 2.1 — Added drift 2.31 + drift_dev + drift_flutter (approved); sqlite3 as a dev dep so host tests load Windows' built-in `winsqlite3.dll`. `AppDatabase` lives in `lib/app/db/`; tables and DAOs in each feature's `data/db/`. Synced writes go through `OutboxDao.recordWrite` (write + outbox append in one transaction). Dates stored as ISO-8601 text. build_runner now needs `--force-jit` (a dependency declares build hooks). CI fails if `drift_schemas/` is out of date.
- 2026-10-05: 2.2 — Expenses are dated by calendar day (UTC midnight; `CalendarDay`, `YearMonth` in `core/clock/`), no future dates. Undo of a swipe-delete *defers* the delete until the snackbar closes (`PendingDeletes`), so undo never has to un-delete a synced tombstone; if the app dies in the window the expense stays. The 6 default categories are domain constants with fixed ids (same on every device, no sync); a stored row with the same id overrides one (for 2.3). Personal currency is `appCurrencyProvider` (TND) until settings exist. Local-DB stream providers use `retry: noRetry` (Riverpod 3 retries by default). The expense list is at `/expenses`, linked from the placeholder home.
- 2026-10-05: 2.3 — Defaults stay domain constants with fixed ids; the first edit to one stores a row and queues an `update` at base version 0, so the server must key categories by (owner, id) (ADR 0001). Categories are never deleted, only archived (hidden from pickers, kept for their expenses); the last active one can't be archived, and restoring checks the name is still free. Names are unique among active categories, ignoring case. Category writes have their own `CategoryFailure`. Use cases read with a one-shot `getAll()` rather than `watchAll().first`. Categories screen is at `/categories`, from the Expenses app bar.
- 2026-10-05: 2.4 — Decided with the user: per-category limits are each category's standing `monthlyLimit` (the 2.1 `budget_category_limits` table stays unused); irregular income counts every month as an estimate with no date; money available = the month's expected income − its spending, no carry-over. The overall limit is per month and carries forward (latest set at or before the month); month budget ids are `budget-YYYY-MM`, so the server must accept a create for an existing id as an update (ADR 0002). Budget and expense screens share the selected month (`MonthBar`). `storageErrorsAsFailures` moved to `core/result/`. Screens: `/budget` (from home) and `/income` (from the budget app bar).
- 2026-10-06: 3.1 — Postgres only, no SQLite fallback (`server_seq` needs a Postgres sequence). Settings come from env vars only; a missing `DJANGO_SECRET_KEY` is an error unless `DJANGO_DEBUG=1`. Tests use `mizan.settings_test`. Smoke tests instead of a literally empty suite, since pytest exits 5 when it collects nothing.
- 2026-10-06: 3.2 — `accounts.User` uses email as the login (no username); a device row (client UUID per install) is upserted at login/sign-up. Server refresh is our own service (rotation race-safe, 401 for deleted users). Local rows aren't tied to an account: 3.6 must decide what happens when a different account signs in. A WorkManager refresh in 3.6 must not race the app's interceptor (single-use refresh tokens).
- 2026-10-06: 3.3 — Personal rows keyed by (owner, entity_id), group rows by entity_id, applied ops by (user, op_id). `budget_category_limits` not mirrored (unused since 2.4). Ledger writes are serialized globally by the seq lock (fine at this scale; ADR 0005 names the alternative).
- 2026-10-06: 3.4 — The app must send `deviceId` with every push (3.6), and should send `amountMinor`, `split` and `shares` together when any of them changes (4.2): the server checks the merged row and rejects `shares_mismatch` otherwise. Unknown fields are rejected, so app/server field drift fails loudly.
- 2026-10-06: 3.5 — Joining a group later needs a backfill: rows written before the joiner's cursor never come through a normal pull. 4.1 must send the group's current rows on join (e.g. a group-scoped `since=0` pull). Removed members get their own member tombstone, then nothing more from the group.
- 2026-10-06: 3.6 — Pulled rows of entities without a local table yet are skipped while the cursor moves on (3.7: their shadows are kept in `server_rows`, so week 4's migration builds the new tables from them). The interceptor re-reads stored tokens before signing out, so WorkManager and the app can't log each other out by racing a refresh.
- 2026-10-06: 4.1 — Groups and members can't be deleted yet (removing a member waits for 4.4: their balance must be 0). Groups need an account; the Groups screen is at `/groups`, from Home's app bar. 4.2/4.4 tables can build from `server_rows` like v4 did.
- 2026-10-06: 4.2 — A shared expense's category is the payer's personal category id (built-ins are the same everywhere; a custom one shows only to its owner). Settlements still have no local table: 4.4 adds it (from shadows) and adds them to the simulation's on-phone balance check.
- 2026-10-06: 4.4 — Removing members is still not possible (it needs a zero balance); left for later polish. The 3.7 simulation note is done: phones add shared expenses and record/undo payments, and group balances (with settlements) sum to 0 on every phone after every step.
- 2026-10-06: 3.7 — Week 4 (4.2/4.4) must extend the simulation with shared expenses and settlements on devices and check group balances sum to 0 on every device. The client now keeps shadow server rows (schema v3); `DJANGO_CONN_MAX_AGE` defaults to 0.
