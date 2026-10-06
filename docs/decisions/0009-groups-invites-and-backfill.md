# ADR 0009: Groups through sync, invites on the server, and a backfill after joining

- Status: accepted
- Date: 2026-10-06
- Task: 4.1 (builds on ADRs 0006, 0008)

## Context

Task 4.1 needs four things. You create a group (name, currency). You invite people by link or QR with an expiring token. They join. You add placeholder members, and a real user can claim one later. Three questions came up:

1. **Should creating a group work offline?** Everything else in the app does.
2. **Who may put a user into a group?** If push could set a member's `userId`, any member could add strangers or take over a placeholder.
3. **How does a joiner get the group's history?** The group's rows were written before the join, so their seqs sit below the joiner's cursor. A normal pull never brings them (the 3.5 note).

## Decision

- **Groups and members are ordinary synced rows.** The app writes them locally, queues them in the outbox, and they reach the server with push. Creating a group queues two ops in one transaction: the group, then the creator's own member row (the founder).
- **Push never adds a user to a group, with one exception.** Anyone may create a group. Its creator may then create their own member row, with `userId` set to themselves, while the group has no claimed member yet. Every other member op must leave `userId` as it is: null for a new placeholder, unchanged on an edit. Otherwise push rejects it as `invalid_field`. Groups and members can't be deleted yet; removing a member waits for settle-up, since their balance must be 0 first.
- **Invites live on the server only** (`GroupInvite`). They aren't synced: an invite is only useful online.
  - `POST /groups/<id>/invites` (optionally with `memberId` to target a placeholder): any active member can make one.
  - `GET /groups/invites/<token>`: a preview to show before joining.
  - `POST /groups/invites/<token>/join`: joins the group.
  - The token is 24 random bytes. It **expires after 7 days** and **works once**.
  - Joining again with an invite you already used returns the same answer, so a lost response is safe to retry. Anyone else gets `invite_used`.
  - An invite for a placeholder **claims** it: the existing member gets the joiner's `userId`, so the placeholder's expenses and balance become theirs. An invite without a placeholder adds a new member.
  - Joining runs under the ledger lock and writes history, like a push, so other members' phones pull the change.
- **Invite links** are `mizan://mizan.app/join/<token>`. Android opens them in the app (intent filter → `/join/:token`). The QR code shows the same link (`qr_flutter`, approved). The second phone scans it with its own camera app, and links can be pasted on the Join screen. No in-app scanner.
- **Backfill.** `GET /sync/pull?group=<id>` returns only that group's rows, from its own cursor, and only to an active member.
  - The app records a backfill in `group_backfills` when a pull shows this account's own member row as new. That happens when it joined, created the group on another phone, or came back.
  - After each normal pull, the app runs every pending backfill to the end.
  - A backfilled row is applied only if it's newer than the shadow already held, because the normal pull may have brought a newer version first.
  - Because the trigger is "my member row appeared", a second phone of the same account backfills too.
- **Schema v4:** `groups`, `members` and `group_backfills`. The migration builds group and member rows from the `server_rows` shadows pulled since 3.6, as ADR 0008 planned. No op could have been queued for them before v4, so the shadow is the row.
- **Groups need an account.** Without one, the Groups screen asks the user to sign in.

## Consequences

- An invite needs the group on the server, so the group must sync first. The app says so (`notSynced`) instead of failing silently.
- A link in a QR code uses a custom scheme. Some camera apps show it as text rather than a link to open. Pasting it on the Join screen always works.
- Shared expenses and settlements still have no local tables (4.2, 4.4). Their shadows are kept, and backfills fetch them too, so those migrations can build from the shadows as well.
- Tests:
  - `server/tests/test_groups.py`: founding a group through push; push can't add users; valid, expired and reused invites; retrying a join; claiming a placeholder.
  - `app/test/features/groups/data/group_sync_test.dart`: a backfill runs once and skips stale rows.
  - The v3 → v4 migration test.
  - `app/test_e2e/join_group_e2e_test.dart`: phone B joins as phone A's placeholder on a real server.
