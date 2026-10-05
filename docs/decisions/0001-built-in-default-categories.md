# ADR 0001: Built-in default categories with fixed ids

- Status: accepted
- Date: 2026-10-05
- Tasks: 2.2, 2.3 (affects 3.3 and 3.4)

## Context

Every install starts with six student categories: food, transport, rent, study, leisure and other. Users can rename them, change their icon or limit, and archive them, like any custom category. Expenses point at a category by id.

The app is offline-first, and one user can have several devices. If each device created the defaults as ordinary rows with fresh UUIDs, a user with two devices would end up with two "Food" categories after the first sync, and their expenses would be split between them.

## Decision

The defaults are **domain constants with fixed ids** (`food`, `transport`, …), the same on every device (`DefaultCategories`). They are not stored rows, and they are never created or synced.

- **Reading:** the repository merges the constants with stored rows. A stored row with a default's id replaces that default in place. Custom categories follow, sorted by name.
- **First change to a default:** store a row with the default's id and queue an **`update`** op (not `create`) at `baseVersion` 0. The op holds only the fields that differ from the built-in values. Every device, and the server, treats each default as existing implicitly at version 0. So the same change from two devices is an ordinary concurrent update, handled by the normal field-merge rule.
- **Custom categories** get UUIDv7 ids and a normal `create` op.

## Consequences

- **Server (3.3 / 3.4):** categories must be keyed by **(owner, id)**, because every user has a `food`. An `update` for a built-in id with no stored row means "start from the built-in default at version 0". The server needs the same default values as the app (name, icon, no limit, not archived) to apply the merge.
- Changing a default's built-in name or icon in a later app version changes it for every user who hasn't edited it. That's acceptable for defaults; edited ones keep their stored values.
- Defaults can't be deleted, only archived. Categories are never deleted, so expenses always keep their category's name and icon.
- At least one category must stay active (`ArchiveCategory` refuses to archive the last one), so the add-expense sheet always has something to pick.
