"""`/sync/pull?since=<cursor>`: what changed since the client's cursor (§6).

Returns every row with `server_seq > since` that the user may see, oldest
first, tombstones included, at most `limit` per page:

- their own personal rows (expenses, categories, income sources, budgets);
- for each group they are an active member of: the group, its members,
  shared expenses and settlements;
- their own member rows in any group, removed ones included, so a phone
  learns it was removed (and then stops getting that group's data);
- history rows of those scopes.

**No gaps.** The client moves its cursor to the last seq of a page, so a page
must never hold seq N while missing a visible row with a smaller seq:

- writes commit in seq order (ADR 0005), so nothing smaller can still appear
  after N is visible;
- the page is read in one REPEATABLE READ transaction, so all its queries see
  the same snapshot. At READ COMMITTED each query would get a fresh one, and a
  commit landing between two queries could put seq 101 on the page but not 100.

**Joining a group** (task 4.1). Rows written to a group before someone
joined have seqs below that person's cursor, so a normal pull never brings
them. `group=<id>` pulls just that group's rows, with its own cursor from 0:
the app runs it once after it learns it joined (3.5's backfill note).

**Pages.** Each source is asked for `limit + 1` rows above the cursor; merged
by seq, the first `limit` are the page and the extra one says whether more
remain.
"""

import heapq
from dataclasses import dataclass
from typing import Callable

from django.db import connection, transaction
from django.db.models import Q

from groups.models import Group, Member

from .entities import ENTITIES
from .models import EntityHistory

DEFAULT_LIMIT = 200
MAX_LIMIT = 500


@dataclass(frozen=True)
class Source:
    entity: str
    rows: Callable  # (user, group_ids) -> queryset
    state: Callable  # row -> dict


def _spec_source(name, rows):
    return Source(name, rows, ENTITIES[name].state)


def _history_state(row):
    """Shaped like the app's entity_history table, plus `kind`."""
    return {
        "id": str(row.pk),
        "entity": row.entity,
        "entityId": row.entity_id,
        "kind": row.kind,
        "field": row.field,
        "oldValue": row.old_value,
        "newValue": row.new_value,
        "changedBy": str(row.changed_by_id) if row.changed_by_id else None,
        "serverSeq": row.server_seq,
        "changedAt": row.changed_at.isoformat().replace("+00:00", "Z"),
    }


def _personal(name):
    model = ENTITIES[name].model
    return _spec_source(name, lambda user, groups: model.objects.filter(owner=user))


def _in_groups(name):
    model = ENTITIES[name].model
    return _spec_source(name, lambda user, groups: model.objects.filter(group_id__in=groups))


SOURCES = [
    _personal("expenses"),
    _personal("categories"),
    _personal("income_sources"),
    _personal("budgets"),
    _spec_source("groups", lambda user, groups: Group.objects.filter(pk__in=groups)),
    _spec_source(
        "members",
        lambda user, groups: Member.objects.filter(Q(group_id__in=groups) | Q(user=user)).select_related("group"),
    ),
    _in_groups("shared_expenses"),
    _in_groups("settlements"),
    Source(
        "entity_history",
        lambda user, groups: EntityHistory.objects.filter(Q(owner=user) | Q(group_id__in=groups)),
        _history_state,
    ),
]


# One group's rows only: `pull(group=...)`.
GROUP_SOURCES = [
    _spec_source("groups", lambda user, groups: Group.objects.filter(pk__in=groups)),
    _spec_source("members", lambda user, groups: Member.objects.filter(group_id__in=groups).select_related("group")),
    _in_groups("shared_expenses"),
    _in_groups("settlements"),
    Source(
        "entity_history",
        lambda user, groups: EntityHistory.objects.filter(group_id__in=groups),
        _history_state,
    ),
]


def pull(user, since, limit=DEFAULT_LIMIT, group=None):
    """`{"changes": [...], "cursor": N, "hasMore": bool}`. Each change is
    `{"entity", "serverSeq", "state"}`; resume with `since=cursor`.

    With `group` (an entity id), only that group's rows, and nothing unless
    the user is an active member of it."""
    # The isolation level can only be set by the statement that starts a
    # transaction. A request always starts one here (ATOMIC_REQUESTS is off);
    # only a caller already inside a transaction (a plain pytest-django test)
    # keeps its own, and test_pull's no-gap test runs without one.
    outermost = not connection.in_atomic_block
    with transaction.atomic():
        if outermost:
            with connection.cursor() as cursor:
                cursor.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY")
        mine = Group.objects.filter(members__user=user, members__deleted=False, deleted=False)
        if group is not None:
            mine = mine.filter(entity_id=group)
        groups = list(mine.values_list("pk", flat=True))
        sources = SOURCES if group is None else GROUP_SOURCES
        batches = [_fetch(source, user, groups, since, limit + 1) for source in sources]

    merged = list(heapq.merge(*batches, key=lambda change: change["serverSeq"]))
    page = merged[:limit]
    return {
        "changes": page,
        "cursor": page[-1]["serverSeq"] if page else since,
        "hasMore": len(merged) > limit,
    }


def _fetch(source, user, groups, since, count):
    rows = source.rows(user, groups).filter(server_seq__gt=since).order_by("server_seq")[:count]
    return [{"entity": source.entity, "serverSeq": row.server_seq, "state": source.state(row)} for row in rows]
