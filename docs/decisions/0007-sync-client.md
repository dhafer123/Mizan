# ADR 0007: The sync client — when it runs, how it applies, whose data it is

- Status: accepted
- Date: 2026-10-06
- Task: 3.6

## Context

The server side is done: push and its conflict rules (ADR 0006), and gap-free pull (ADR 0005). The app needs to push its outbox, pull and apply changes without hiding unsynced local edits, decide when to do all that, and handle a phone that switches accounts. The user approved `connectivity_plus` and `workmanager`. They also chose **wipe and pull** for account switches.

## Decision

**One sync = push, then pull** (`SyncNow`). Pushing first means the pull brings back the server's merged result of this phone's own changes.

- **Push.** Pending ops go out oldest first, in batches of 200 (the server's limit). The push carries the per-install `deviceId` (ADR 0006) and repeats until the outbox has no pending ops.
  - `applied` and `merged` ops leave the outbox.
  - `rejected` ops stay, marked rejected, with the server's reason. The UI counts them as "couldn't be saved on the server".
  - A transport or server failure puts the batch back to pending with `attempts + 1`.
  - Ops left in `sending` by a killed app are reset to pending at the start of the next push. Re-sending is safe because the server dedupes by op id.
- **Pull.** Pages follow the cursor until `hasMore` is false. Each page is applied in one drift transaction, together with its cursor. A failure leaves the cursor where it was, so the page is pulled again.
  - **Rebase:** before a pulled row is written, any ops for it still pending or sending are laid on top (`rebaseRow`). An unsynced local edit stays visible; it was based on the old version, and the server merges it when it's pushed. Rejected ops are not re-applied, so the server's row wins.
  - The page is applied only while the local data still belongs to the account being synced. Otherwise it fails with `accountChanged`, and the scheduler starts over for the new account.
  - Rows for entities this app version has no table for yet (groups, members, shared expenses, settlements until week 4) are skipped, but the cursor still moves past them. **So the migration that adds such a table must reset `sync_state.cursor` to 0**, and the next pull fetches everything again. Applying a row is an upsert, so that's safe.
- **When** (`SyncScheduler`, pure Dart, tested with fake timers):
  - when an account signs in;
  - when the network comes back (`connectivity_plus`);
  - 2 s after the last local write, so a burst of edits is one sync;
  - when the app resumes;
  - "Sync now" in the status sheet;
  - every 15 minutes in the background (WorkManager, only with a network).

  Only one sync runs at a time; a trigger during a run queues exactly one more. After a failure it retries with exponential backoff: 2 s, doubling, up to 5 min, ±20 % jitter. Offline and server errors retry; an ended session or an account change doesn't.
- **Background sync.** WorkManager runs `backgroundSyncDispatcher` in another isolate, which builds the same Riverpod providers.
  - The database is opened with drift's `shareAcrossIsolates`, so the app and the background task share one SQLite connection.
  - Refresh tokens are single-use (ADR 0004), so the app and the background task could race to refresh. When a refresh is rejected, the interceptor re-reads storage first. If storage now holds a different refresh token, the other isolate won the race, and the request is retried with that pair instead of signing out.
- **Whose data.** `sync_state.accountId` records which account the synced data belongs to. When an account is ready to sync:
  - **never synced** (local-only mode until now): the data is kept, and the outbox (every op since install) uploads into the account;
  - **same account:** nothing changes;
  - **another account:** the synced tables, outbox, history and cursor are wiped, then the new account is pulled.

  The logout dialog warns when changes haven't synced yet: they stay on the phone, but signing in to a different account deletes them.
- **UI.** A status icon in Home's app bar shows signed out, offline, syncing, up to date, changes waiting (with a badge) or a problem. Its sheet shows the reason, waiting and refused counts, the last sync time, and "Sync now" or "Sign in".
- **Schema v2:** `sync_state.account_id`, `entity_history.kind` (the server's `created` / `changed` / `overwritten` / `deleted` / `restored` / `discarded`), and `outbox.reject_reason`. The migration is tested on a v1 database with data.

## Proof

`app/test_e2e/offline_sync_e2e_test.dart` runs the real repositories, use cases, dio and scheduler against a real Django server:

1. Sign up a fresh account.
2. Turn on "airplane mode": a network adapter that refuses every request, plus the connectivity flag set to offline.
3. Make 5 edits through the use cases: add 3 expenses, edit one, delete one.
4. Check the outbox holds 5 ops and the server has nothing.
5. Go back online and wait for the outbox to drain.
6. Ask the server directly: it has the 3 expenses with the edit and the delete, and its history shows exactly those 5 changes, in order.

It runs in CI (`.github/workflows/e2e.yml`, with Postgres and Django), and locally with `MIZAN_E2E_URL`.

## Consequences

- Background sync costs battery and data every 15 minutes while signed in. WorkManager's network constraint and the OS's own batching keep that low.
- When week 4 adds group tables, its migration must reset the cursor (see Pull).
- A rejected op stays in the outbox for the UI. Nothing clears old rejections yet; a "dismiss" action can come with the polish in 6.2.
