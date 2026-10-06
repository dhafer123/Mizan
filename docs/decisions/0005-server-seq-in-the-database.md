# ADR 0005: `server_seq` and `version` are set by Postgres triggers, and writes commit in seq order

- Status: accepted
- Date: 2026-10-06
- Task: 3.3 (used by 3.4, 3.5)

## Context

Pull returns "every change with `serverSeq > cursor`" (ARCHITECTURE.md §6), and the client then moves its cursor to the highest seq it saw. That only works if two things hold:

1. **Every write gets a new seq.** A write that keeps its old seq is never pulled again.
2. **Once a reader can see seq N, no row with a smaller seq can still appear.** A sequence alone doesn't guarantee this. Transaction A takes seq 10, then transaction B takes seq 11 and commits first. A pull now returns 11 and moves the cursor to 11. When A commits, row 10 sits below the cursor and is never pulled. That breaks convergence silently.

## Decision

- **One global sequence**, `mizan_server_seq`, shared by every synced table (expenses, categories, income sources, budgets, groups, members, shared expenses, settlements) and by the history table. A single cursor covers them all.
- **A `BEFORE INSERT OR UPDATE` trigger on every synced table** sets `version` (1 on insert, +1 on each update) and `server_seq`. Python never sets either one; `SyncedModel.save()` reads them back. ORM saves, `bulk_create`, `QuerySet.update` and raw SQL are all covered.
- **Commit order = seq order.** The seq comes from `mizan_next_server_seq()`, which first takes `pg_advisory_xact_lock`. The lock is held until the transaction ends, so a second writer waits for the first to commit or roll back before it gets a seq. A rolled-back write leaves a gap in the sequence, which is harmless; a seq is never reused.
- **Insert-only is enforced in the database.** A `BEFORE UPDATE` trigger raises on settlements, history rows and the applied-op log.
- **Keys.** Personal rows are unique on `(owner, entity_id)` (ADRs 0001, 0002). Group-side rows are unique on `entity_id`. The applied-op log is unique on `(user, op_id)`, so nobody can replay another user's op id to read its stored result.
- **CHECK constraints are a backstop**, not the validator. The sync service (3.4) checks every op and returns a reason; the database only refuses rows that must never exist. A CHECK passes when its expression is NULL, so conditions on nullable columns say `IS NOT NULL` explicitly. A test caught this for a monthly income with no day.

## Consequences

- Ledger writes are serialized globally, one transaction at a time, from the first synced write to commit. That's fine for this app's load. Each push op runs in its own short transaction (§6), so the lock is held only briefly. If it ever becomes a bottleneck, the alternative is to keep the parallel sequence and have pull stop below the oldest in-flight transaction (`pg_snapshot_xmin`).
- Reads (pull) never take the lock.
- `version` counts every server write, including merges. A client's `baseVersion` is compared against it in 3.4.
- Account deletion (6.4) has to delete settlements and history, which the insert-only triggers allow, since they only block UPDATE.
- Tests: `tests/test_server_seq.py` covers strictly increasing seqs across tables and writes, stamping on every write path, and a two-thread test showing that a second writer waits for the first commit and gets a larger seq. The test fails if the lock is removed (checked by hand). `tests/test_ledger_migrations.py` checks that the migrations unapply and reapply cleanly with every trigger in place.
