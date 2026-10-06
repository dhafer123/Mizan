# ADR 0008: Sync simulation against both servers, and shadow rows on the client

- Status: accepted
- Date: 2026-10-06
- Task: 3.7 (changes 3.6's client; see ADR 0007)

## Context

§11 asks for 2–3 fake clients and a fake server running random interleavings, checking the four invariants of §6 on 1,000 scenarios per CI run. The app has no group tables until week 4, so the "group balances sum to 0 on every device" part can't run on devices yet. The user chose: simulate the **real** client code now, check money integrity on what exists, check group balances on the server, and extend in week 4.

## Decision

**The harness** (`app/test/sync_sim/`):

- **Phones:** each is the app's real stack: an in-memory drift database, DAOs, repositories, use cases, `SyncRepositoryImpl`, `SyncLocalStore` and `SyncApi`. Only time and the network are fake.
- **Network** (`SimLink`): it can go offline, and it loses 10 % of push responses *after* the server applied them. That forces real retries through the idempotency path.
- **Fake server** (`FakeSyncServer`): a Dart port of `push.py` and `pull.py` with the same rules. Its page size is random, so clients have to follow `hasMore`. A "group actor" also pushes shared expenses and settlements straight to it. Some of these are deliberately bad: a stale amount-only edit whose shares no longer add up, and a reversal that isn't a mirror.
- **Scenarios:** seeded and random. Each has 2–3 phones of one account and 15–60 steps. A step is one of:
  - an edit through the use cases: add, edit or delete an expense; rename or archive a category (built-ins included); set a month's budget;
  - push, pull, or both, in random order;
  - going offline or online;
  - a group op (fake server only).

  Then everything syncs until no op waits, and the four invariants are checked:
  1. **Convergence:** every phone holds the same rows and history, equal to what the server returns from a pull at cursor 0.
  2. **No lost writes:** every op any phone ever queued is applied, merged, or rejected with a reason. A rejected edit of a deleted row is kept in history as `discarded`, and the phone shows the same refusal.
  3. **Money integrity:**
     - after every step, every amount on every phone is whole minor units in TND, and positive where it must be;
     - after sync, each phone's total equals the server's;
     - on the fake server, group balances (computed with the app's own `ComputeBalances`) sum to 0 after every step.
  4. **Idempotency:** pushing every op again, twice, changes nothing on the server and returns the same results both times.
- **Same checks on both servers.** The checks only use what a client can see (pull, push results), so the same scenarios run against the real Django server. CI runs 1,000 scenarios on the fake per run (`app` job, about 2 min, a new seed each run) and 50 on the real server (`e2e` job). A failure prints its seed and the last 40 steps, and dumps every outbox and the server history. `SYNC_SIM_SEED=<seed> SYNC_SIM_SCENARIOS=1` replays it.
- **Coverage is printed.** Each run prints how often it hit the hard paths, so a harness that stopped reaching them would show. A typical 1,000-scenario run: about 16,800 ops, 370 lost responses, 650 merges, 420 same-field overwrites, 110 edits rejected after a delete.

## What it found (all fixed, each with a regression unit test)

1. **Pulled nulls didn't clear local values.** drift's `insertOnConflictUpdate(row)` leaves nulls out of the `ON CONFLICT` update. A limit removed or a note cleared on another phone stayed set here, under the server's version number. Fix: upsert with `toCompanion(false)`. `BudgetsDao.saveBudget` had the same bug.
2. **A rejected edit stuck on a tombstone.** Rebase laid a queued edit on top of a pulled tombstone; the server then rejected it as `deleted`. The server row never changed again, so no pull fixed it.
3. **A lost response left a stale value.** The server applied an op, but the response was lost. A newer edit from another phone landed, and the pull rebased the still-queued op on top of it. The retried push was then acked from the stored (older) result, and the op's value stayed for good.

Fixing 2 and 3 properly took a design change in the client. **The client keeps a shadow copy of every server row** (`server_rows`, schema v3). The row the app shows is always that shadow with the still-queued ops on top. It's rebuilt when a pull brings a new version, and when an op leaves the outbox, accepted or refused. A push result's state replaces the shadow only if it isn't older, because a replayed result can be. Rows pulled before v3 have no shadow, so their own `serverSeq` is compared instead.

4. **Postgres ran out of connections on the real server.** `CONN_MAX_AGE = 60` (from 3.1) keeps one connection per thread, and the dev server starts a thread per request. A long run used up all 100 Postgres slots and sign-up returned 500. Fix: `DJANGO_CONN_MAX_AGE`, default 0. Only enable it with a fixed worker pool.

## Consequences

- The fake server must follow `push.py` and `pull.py`. The real-server run in CI is what catches it drifting.
- Week 4 adds group tables. Since shadows are kept for every entity, including ones without a table yet, that migration can **build the new tables' rows from `server_rows`** instead of resetting the cursor (this replaces the cursor-reset note in ADR 0007). Then this harness gets an on-device group-balance check. TASKS.md has the note.
- Every pulled row is stored twice, once as the row and once as its shadow. For a student's data that's a few hundred KB at most.
