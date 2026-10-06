# ADR 0010: The split's wire format, and the server recomputes shares

- Status: accepted
- Date: 2026-10-06
- Task: 4.2 (builds on ADR 0006)

## Context

A shared expense stores both its `split` (the rule as entered) and its `shares` (what the rule gave). Until now, the server only checked that the shares add up to the amount, and that the split had a known `type`. A client with a bug, or a tampered request, could store an "equal" split with 70/30 shares. Every device would then show balances that don't match what the expense says. CLAUDE.md rule 8 says the server re-validates everything.

## Decision

- **One JSON shape for splits, the same in the app and on the server:**
  - `{"type": "equal", "memberIds": [...]}`
  - `{"type": "exact", "amounts": {memberId: minor}}`
  - `{"type": "percentage", "basisPoints": {memberId: bp}}`, adding up to 10000
  - `{"type": "shares", "weights": {memberId: w}}`

  `shares` is `{memberId: minor}` for every member the split names, zero shares included. No doubles anywhere.
- **The server recomputes the shares from the split** (`expected_shares` in `server/sync/entities.py`). It uses the app's `ComputeShares` rule: largest remainder, ties to the lowest member id. It rejects:
  - `shares_mismatch`: the shares don't add up to the amount (checked first, as before);
  - `invalid_split`: the split is malformed (wrong keys, percentages that don't total 100 %, all weights 0, exact amounts that don't add up);
  - `split_mismatch`: the shares add up but aren't what the split gives.
- **The app stores `split` and `shares` as JSON text columns** that serialize as objects (a drift `TypeConverter.json2`). A synced row's payload is then exactly what the server expects. Schema v5 adds `shared_expenses` and builds it from the `server_rows` shadows, like v4 did for groups.
- **The add sheet previews each share live with `ComputeShares`**, the same rule the use case and the server apply. Save stays disabled until the split works out.

## Consequences

- The rounding rule now lives in three places: the app (`ComputeShares`), the server (`expected_shares`), and the simulation's fake server. They must agree. Two tests guard that:
  - `app/test_e2e/join_group_e2e_test.dart` sends rounded equal and percentage splits to the real server.
  - The simulation pushes about 2,600 random device-made shared expenses per run to the fake server, and all are accepted.
- Editing a shared expense (not in 4.2) must send `amountMinor`, `split` and `shares` together (ADR 0006). Also, drift's `changedSyncFields` compares map values by identity, so an edit diff has to compare split and shares by value.
- Tests:
  - `server/tests/test_push_entities.py::test_the_server_recomputes_shares_from_the_split`
  - the add sheet's widget tests, one per split type
  - `AddSharedExpense` use case tests
  - the v4 → v5 migration test
  - the simulation now checks that group balances sum to 0 on every phone after every step (settlements join in 4.4)
