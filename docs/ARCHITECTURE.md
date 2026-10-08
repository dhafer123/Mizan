# Architecture — Mizan (offline-first student finance app)

> "Mizan" is a working name (Arabic for *balance*). Rename freely.

## 1. Goals and non-goals

**Goals**
- Track personal spending against a monthly budget, and warn **before** money runs out.
- Share expenses with roommates and friends, with the fewest payments to settle up.
- **Offline-first:** every feature works without a network. Sync is a background detail.
- Fast input: voice and receipt photos, processed **on the device**.
- Correctness you can prove: money never drifts, all devices converge, balances always sum to 0.

**Non-goals for v1**
- Bank connections and investments.
- Multi-currency inside one group (a group has one currency).
- A web client.

## 2. System overview

```
┌──────────────────────────── Phone (Flutter) ────────────────────────────┐
│ Presentation   screens + Riverpod notifiers                             │
│      │                                                                  │
│ Domain         entities, use cases, repository interfaces  (pure Dart)  │
│      ▲                                                                  │
│ Data           drift (SQLite) DAOs, outbox, sync client, API client,    │
│                on-device AI (speech, OCR, LLM)                          │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │ HTTPS, JSON (only when online)
┌─────────────────────────────────▼───────────────────────────────────────┐
│ Server (Django REST Framework + PostgreSQL, Docker)                     │
│ auth (JWT) · sync push/pull · groups + invites · FCM push notifications │
└─────────────────────────────────────────────────────────────────────────┘
```

The **local SQLite database is the source of truth for the UI**. Screens never wait for the network. The server's job is to order changes, resolve conflicts, and pass them to the other devices.

## 3. Clean architecture (Flutter app)

### Dependency rule

```
presentation ──► domain ◄── data
```

- **domain**: pure Dart. No Flutter, drift, http or plugin imports. Contains entities, value objects, use cases and repository **interfaces**. All business rules live here: money, splits, balances, debt simplification, forecasting, budget alerts.
- **data**: implements the domain interfaces using drift, the sync client, the HTTP API and the AI plugins. Maps between DB rows / DTOs and domain entities.
- **presentation**: widgets and Riverpod notifiers. It calls use cases only, never DAOs or APIs directly.
- **Wiring**: Riverpod providers in `app/di/` bind each interface to its implementation. Tests override these providers with fakes.

### Folder layout

```
mizan/
  app/                              # Flutter app
    lib/
      main.dart
      app/                          # router, theme, di/ (providers), bootstrap
      core/
        money/                      # Money value object, rounding, formatting
        result/                     # Result<T, Failure>, Failure types
        ids/                        # UUIDv7 generator
        clock/                      # Clock interface (testable "now")
      features/
        expenses/   {domain, data, presentation}
        budget/     {domain, data, presentation}   # budgets, income, forecast, alerts
        groups/     {domain, data, presentation}   # groups, splits, balances, settle-up
        sync/       {domain, data}                 # outbox, push/pull, conflict handling
        quick_input/{domain, data, presentation}   # voice, receipt, categorization
        auth/       {domain, data, presentation}
        settings/   {presentation}                 # app lock, export, account
    test/                           # mirrors lib/
    integration_test/
  server/                           # Django project
    mizan/ (settings)  accounts/  ledger/  sync/  groups/  notifications/
    tests/
    docker-compose.yml
  docs/
    ARCHITECTURE.md  METRICS.md  decisions/   # short ADRs, one per big decision
```

Each feature folder has the same shape:

```
features/groups/
  domain/
    entities/        group.dart, member.dart, shared_expense.dart, settlement.dart
    value_objects/   split.dart
    repositories/    group_repository.dart          (abstract)
    usecases/        add_shared_expense.dart, compute_balances.dart, simplify_debts.dart
  data/
    db/              groups_dao.dart (drift)
    repositories/    group_repository_impl.dart
    mappers/
  presentation/
    group_list/  group_detail/  add_expense/  settle_up/
```

## 4. Domain model

### Money
- `Money(int minorUnits, Currency currency)`. TND has 3 decimals, so 4.500 DT = `4500`.
- **Never use `double` for money.** Parsing and formatting happen only at the UI edge.
- Splitting uses **largest remainder, ordered by member id**: 100.000 split 3 ways gives 33.334 / 33.333 / 33.333, and every device computes the same result.

### Entities

| Entity | Key fields |
|---|---|
| `Expense` (personal) | id, amount, categoryId, date, note, source (manual / voice / receipt) |
| `Category` | id, name, icon, monthlyLimit? |
| `IncomeSource` | id, name, amount, schedule (monthly on day N / one-off / irregular) |
| `Budget` | month, totalLimit, per-category limits |
| `Group` | id, name, currency, members |
| `Member` | id, groupId, userId? (null = placeholder), displayName |
| `SharedExpense` | id, groupId, payerId, amount, date, category, splitType, shares[] |
| `Settlement` | id, groupId, fromMemberId, toMemberId, amount, date, reversesId? |

All synced entities also carry the sync metadata: `version`, `deleted` (tombstone), `updatedBy`, `serverSeq`.

### Core rules (pure functions, heavily tested)

| Function | Rule |
|---|---|
| `computeShares(amount, splitType, members, inputs)` | The shares sum to exactly `amount`. |
| `computeBalances(expenses, settlements)` | balance = paid − share ± settlements. **The sum of all balances is always 0.** |
| `simplifyDebts(balances)` | Greedy: biggest debtor pays biggest creditor. At most n − 1 transfers. Applying them makes every balance 0. |
| `mySpending(month)` | Personal expenses + **my shares** of group expenses (not what I paid for others). |
| `forecastRunOut(balance, history, incomes, recurring, debts)` | Returns the projected run-out date with a low–high range (see §7). |
| `budgetAlerts(state)` | Category ≥ 80% used, forecast before next income, unusual spending (an expense > 2.5× its category's 4-week median). Sent once per situation, at most one a day per type, from the app and the background sync (ADR 0013). |

## 5. Local storage (drift)

- One table per entity, plus:
  - `outbox`: `opId` (UUID), `entity`, `entityId`, `opType` (create / update / delete), `changedFields` (JSON), `baseVersion`, `createdAt`, `attempts`, `status`.
  - `sync_state`: `cursor` (last `serverSeq` pulled), `lastSyncAt`.
  - `entity_history`: change log shown in the UI ("Ali changed amount 120 → 150").
  - `server_rows`: each synced row as the server last sent it. The row the UI shows is that plus the still-queued outbox ops, rebuilt whenever either changes (ADR 0008).
  - `group_backfills`: groups this account just joined whose older rows still need a group-scoped pull (ADR 0009).
- Every user action runs in **one transaction**: write the entity **and** append to the outbox. This is the core offline-first guarantee: no change is ever made without being queued for sync.
- Balances and totals are **never stored**. They are computed from rows (and cached in memory if needed).

## 6. Sync protocol

### Principles
- IDs are generated on the client (**UUIDv7**), so records can be created offline without asking the server.
- Ordering uses a **server-assigned global sequence** (`serverSeq`, from a Postgres sequence on every write), **not device clocks**. Phone clocks are wrong too often to trust.
- Operations are **idempotent**: the server records the `opId`s it has applied, so a retried push is harmless.

### Push: `POST /sync/push`

```json
{ "deviceId": "…",
  "ops": [ { "opId": "…", "entity": "shared_expenses", "entityId": "…",
             "opType": "update", "baseVersion": 3,
             "changedFields": { "amountMinor": 150000 } } ] }
```

`deviceId` tells a concurrent edit (another device) from the same device's earlier op: the app keeps a row's version until it pulls, so ops from one device can share a `baseVersion` (ADR 0006).

The server applies the ops in order, each in its own transaction:

1. `opId` already applied? Return the stored result (idempotency).
2. Check permissions: the user owns the record, or is a member of its group.
3. Nothing changed by another device since `baseVersion`? Apply the op, then `version + 1` and a new `serverSeq`.
4. Otherwise it's a **conflict**. Apply the conflict policy below, write `entity_history`, and return the winning state.

It returns a result per op: `applied` / `merged` / `rejected` (with a reason) and the entity's current state.

### Conflict policy

| Case | Rule |
|---|---|
| Two edits change **different fields** | Merge both. |
| Two edits change **the same field** | The later one (by server receive order) wins. The loser is kept in history and shown to the user. |
| Edit vs delete | **Delete wins.** The expense can be restored from history. |
| Settlements | Insert-only: never edited or deleted. A mistake is fixed with a reversing settlement. No conflicts possible. |
| Member removed from a group | Their pending ops for that group are rejected with `not_a_member`. |

### Pull: `GET /sync/pull?since=<cursor>&limit=<n>`
- Returns every change with `serverSeq > cursor` in the user's scopes (their own records plus the groups they belong to), including tombstones and history. It's paginated: `{"changes": [{"entity", "serverSeq", "state"}], "cursor", "hasMore"}`, with `limit` 200 by default and 500 at most.
- A page is read from one snapshot (REPEATABLE READ). Writes commit in `serverSeq` order (ADR 0005), so a page never skips a row.
- A member removed from a group still gets their own member row (as a tombstone), then nothing more from that group.
- The client applies the changes in one transaction, then **re-applies pending outbox ops on top** (rebase), so local unsynced edits stay visible.
- The client stores the new cursor.
- **Joining a group:** the group's older rows sit below the joiner's cursor. `GET /sync/pull?group=<id>&since=<n>` returns only that group's rows, to active members. The app runs it from 0 once it pulls its own new member row (ADR 0009).

### When sync runs
On app start, when coming back online (connectivity listener), after a local write (debounced 2 s), when an FCM "data changed" push arrives, and periodically with WorkManager. Failures retry with exponential backoff. A push is only a signal (`{type: "sync"}`). It never carries rows, so sync stays the only data path. Without a Firebase config, push is off and the other triggers remain (ADR 0011).

### Invariants (tested)
1. **Convergence:** after all devices push and pull, every device has identical rows.
2. **No lost writes:** every op is applied, merged, or recorded in history with a reason.
3. **Money integrity:** group balances sum to 0 on every device at all times.
4. **Idempotency:** pushing the same op twice changes nothing.

## 7. Forecasting

The question is: when does my available money hit 0?

- **Available now** = money left this month (as on Home) + money owed to me (optional toggle). Recurring costs are subtracted on their day during the projection (ADR 0012).
- **Daily variable spend**: an exponentially weighted average over the last 28 days, **split by weekday vs weekend** (students spend differently on weekends), excluding known recurring items.
- **Projection**: step day by day from tomorrow, subtracting the expected spend and recurring costs and adding income from later months (this month's is already in money left), until the balance goes below 0 or the horizon (60 days) ends.
- **Range**: repeat the projection with the rates scaled by the 25th and 75th percentile of 7-day spending totals (daily totals are too lumpy), giving a "run-out between the 21st and the 25th" range (ADR 0012).
- **Cold start** (< 14 days of data): use the budget as the spending rate and say so in the UI.
- **Evaluation (backtest)**: on real usage data, at each day *d* forecast the run-out date using only data before *d*, then compare with the actual date. Report the mean absolute error in days.

It's a pure Dart function with no ML library, which keeps it explainable and testable. A learned model can replace it later behind the same interface.

## 8. Quick input (on-device AI)

```
voice  ─► speech-to-text ─┐
                          ├─► parser ─► categorizer ─► confirmation sheet ─► SaveExpense use case
receipt ─► OCR (ML Kit) ──┘
```

- **Speech-to-text**: the platform recognizer (`speech_to_text`), preferring offline language packs. It sits behind a `SpeechRecognizer` interface so Whisper can be swapped in later.
- **Parser, in 2 tiers:**
  1. A deterministic rule parser handles amounts, "and" / "et" / "w" separators and known merchant keywords. It's fast, free and covers most simple phrases.
  2. If the rules give low confidence, fall back to an on-device LLM (`flutter_gemma`, small model) that returns JSON matching a fixed schema, validated before use.
- **Receipt**: ML Kit text recognition (on-device), then a rule extractor for TOTAL / date lines, with an LLM fallback for messy receipts.
- **Categorizer**: (1) the user's own memory (merchant or keyword → category, learned from corrections), then (2) rules, then (3) LLM.
- **Always confirm**: nothing parsed is saved without the user seeing it and being able to edit it.

## 9. Server (Django)

| App | Responsibility |
|---|---|
| `accounts` | Sign-up and login (email + password), JWT access and refresh (simplejwt), devices (FCM tokens) |
| `ledger` | Server-side models mirroring synced entities, plus `version`, `server_seq`, `deleted` |
| `sync` | `/sync/push`, `/sync/pull`, applied-op log, conflict policy, history |
| `groups` | Invite tokens (link / QR, single-use, 7 days), joining, placeholder claiming. Groups and members themselves sync through push (ADR 0009) |
| `notifications` | FCM pushes (HTTP v1, after commit, off the request thread): "data changed" to members' other phones, "new shared expense", "someone joined", weekly settle-up reminders (ADR 0011) |

- PostgreSQL, with Docker Compose for local development.
- The server **re-validates** domain rules (shares sum to the amount *and* are what the split gives, member belongs to the group). It never trusts the client. Split JSON: ADR 0010.
- pytest covers the API and every conflict case in §6.

## 10. Security and privacy

- Voice, receipts and categorization never leave the phone.
- App lock with PIN or biometrics (`local_auth`). Tokens are kept in `flutter_secure_storage`.
- The server stores only what sync needs. No receipt images are uploaded.
- CSV export of all your data, and account deletion that removes your server data.

## 11. Testing strategy

| Level | What | Tools |
|---|---|---|
| Domain unit | Money, splits, balances, simplification, forecast, alerts, parser | `test`; property-based tests with `glados` (random inputs, invariants hold) |
| Data | DAOs, outbox transaction, mappers | drift in-memory DB |
| Sync simulation | 2–3 fake clients + an in-memory fake server running random op interleavings with offline periods; assert the 4 invariants in §6 | Dart test harness, 1,000+ random scenarios per CI run |
| Server | API, permissions, conflict cases, idempotency | pytest, pytest-django |
| Widget / integration | Add expense, settle up, offline then online flow | `flutter_test`, `integration_test` |
| CI | analyze, test (app + server), coverage on `domain/` ≥ 90% | GitHub Actions |

## 12. Key decisions (write a short ADR for each in `docs/decisions/`)

1. Server-assigned sequence instead of device timestamps for ordering.
2. Field-level merge, with last write wins per field and visible history (not CRDTs: simpler, and enough for this data).
3. Delete wins over a concurrent edit, with restore available from history.
4. Insert-only settlements.
5. Integer minor units, with largest-remainder rounding by member id.
6. A two-tier parser (rules first, LLM fallback) for speed and predictability.
