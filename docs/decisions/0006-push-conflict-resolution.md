# ADR 0006: How `/sync/push` decides, field by field

- Status: accepted
- Date: 2026-10-06
- Task: 3.4 (affects 3.6, 4.2)

## Context

§6 gives the conflict policy: different fields merge, the same field goes to the later arrival, a delete wins over an edit, settlements are insert-only, and a removed member's ops are rejected. Implementing it surfaced three questions:

1. **What counts as "concurrent"?** The app keeps a row's `version` until it pulls. A phone that edits an expense twice offline sends two ops with the same `baseVersion`. Comparing `baseVersion` with the current version alone would call the phone's second edit a conflict with its own first edit.
2. **Which fields changed since `baseVersion`?** The server needs this to tell a same-field conflict (keep the loser in history) from a merge of different fields.
3. **How do these rules interact with ADRs 0001 and 0002**, where a category or month budget can exist without a stored row, or be created on two devices?

## Decision

- **A push carries the device id:** `{"deviceId", "ops": [...]}`. Every history row records the device that made the change. An op is concurrent with a change only if that change came from **another device** and happened after the op's `baseVersion`. A device's own ops are already ordered, so they are applied in order and reported as `applied`.
- **Every write leaves history**, recording the entity's new `version` and the device that made it:
  - `created`, `restored` and `deleted` for whole-row events;
  - one `changed` row per field that changed;
  - `overwritten` for a field that another device had changed concurrently;
  - `discarded` for each field of an edit that arrived after a delete.

  The server finds conflicting fields by reading other devices' history rows with `version > baseVersion`. A `created` or `restored` row counts as changing every field: two devices creating `budget-2026-10` is a same-field conflict.
- **Results:**
  - `applied`: no other device got in between.
  - `merged`: another device got in between, and this op was still applied on top, so it wins any same-field conflict.
  - `rejected`, with a `reason` and sometimes a `field`. Every result includes the row's current `state`, shaped like the app's drift row, except when the user isn't allowed to see it (`not_a_member`, `not_found`).
- **Delete wins.** A delete is applied whatever the edits. An edit arriving after a delete is rejected with reason `deleted`, and its values are kept as `discarded`. A `create` on a tombstoned id restores the row (this is "restore from history").
- **Built-in categories** exist at version 0 with the app's default values. The server keeps a copy of those values, and a test reads the app's Dart file to check they still match. The first `update` stores the row. Categories can't be deleted.
- **A `create` for an id that already exists** (ADR 0002) is handled as an update with `baseVersion` 0. Settlements are the exception: an identical re-send is `applied`, a different one is `already_exists`, and any update or delete is `insert_only`.
- **Validation runs on the merged row**, not just the incoming fields. That covers schedule consistency, budget month matching the id, shares summing to the amount, group currency, membership and reversal mirroring. Unknown fields and sync metadata are rejected as `unknown_field`, so a field-name mismatch between app and server fails loudly. Group references (`groupId`, a budget's `month`) are immutable.
- **Atomicity.** Each op runs in one transaction that first takes the ledger lock (ADR 0005), then reads, merges, writes, and records the applied-op log. A concurrent duplicate of the same op fails on the `(user, opId)` unique key and replays the stored result.
  - Two tests run ops concurrently in threads. The one with simultaneous same-field edits fails without the lock (checked by hand).
- **A malformed op** (bad `opId`, type or `baseVersion`) is rejected on its own as `invalid_op`, matched by position. It isn't recorded, since there may be no usable op id. A bad envelope (no `deviceId`, more than 200 ops) is a 400.

## Consequences

- The sync client (3.6) must send `deviceId` (the per-install id from ADR 0004). After a push, it should take each result's `state.version` as the row's new base, or rely on the pull that follows.
- Shared expenses (4.2) should send `amountMinor`, `split` and `shares` together. Otherwise a merge with another device's amount change can produce shares that don't add up, and the op is rejected with `shares_mismatch`. It isn't lost: the reason is in the applied-op log.
- History grows with every change. That's fine for this app. A future cleanup could drop history for rows deleted long ago.
