"""`/sync/push`: apply a device's ops, one transaction each (ARCHITECTURE.md §6).

For each op:

1. Already applied (same user, same opId)? Return the stored result.
2. Permission: personal rows are looked up within the user's own rows; group
   rows need the user to be an active member of the group (`not_a_member`).
3. Apply it with the conflict policy:

   | Case                                  | Result                                     |
   |---------------------------------------|--------------------------------------------|
   | nothing changed by another device     | applied                                    |
   | since baseVersion                     |                                            |
   | different fields changed concurrently | merged: both kept                          |
   | same field changed concurrently       | merged: this op wins (later arrival); the  |
   |                                       | value it replaces goes to history          |
   |                                       | as `overwritten`                           |
   | edit after a delete                   | rejected `deleted`; values kept in history |
   |                                       | as `discarded`                             |
   | delete after (or during) an edit      | deleted (delete wins)                      |
   | settlement update/delete              | rejected `insert_only`                     |
   | group op from a removed member        | rejected `not_a_member`                    |

"Concurrent" means changed by *another device* since the op's baseVersion.
A device's own earlier ops are not conflicts: the app keeps its local
version until it pulls, so several ops from one device share a baseVersion.

Each op runs under the ledger lock (sync/db.py), so reading the row, merging
and writing can't interleave with another op. The result is stored in the
applied-op log in the same transaction, so a retry replays it exactly.
"""

import uuid
from dataclasses import dataclass

from django.db import IntegrityError, transaction

from groups.models import Group, Member

from .db import lock_ledger
from .entities import ENTITIES, GROUP, Context, RowInvalid
from .fields import ENTITY_ID
from .models import AppliedOp, EntityHistory

OP_TYPES = {"create", "update", "delete"}
MAX_OPS = 200

# Fields the server owns; an op never sets them.
SYNC_METADATA = {"version", "deleted", "updatedBy", "serverSeq"}

APPLIED, MERGED, REJECTED = "applied", "merged", "rejected"


@dataclass(frozen=True)
class Op:
    op_id: uuid.UUID
    device_id: uuid.UUID
    entity: str
    entity_id: str
    op_type: str
    base_version: int
    changed: dict


class Rejected(Exception):
    def __init__(self, reason, field=None, state=None):
        super().__init__(reason)
        self.reason = reason
        self.field = field
        self.state = state


def push(user, device_id, ops):
    """One result per op, in order. `device_id` is the sending phone's id."""
    return [_process(user, device_id, raw) for raw in ops]


def _process(user, device_id, raw):
    try:
        op = _parse(raw, device_id)
    except Rejected as e:
        # Too malformed to record: there may be no usable op id.
        return _result(raw if isinstance(raw, dict) else {}, REJECTED, reason=e.reason, field=e.field)

    stored = AppliedOp.objects.filter(user=user, op_id=op.op_id).first()
    if stored is not None:
        return stored.result

    try:
        with transaction.atomic():
            lock_ledger()
            result = _apply_and_describe(user, op)
            AppliedOp.objects.create(
                user=user,
                op_id=op.op_id,
                entity=op.entity,
                entity_id=op.entity_id,
                op_type=op.op_type,
                status=result["status"],
                reason=result.get("reason", ""),
                result=result,
            )
    except IntegrityError:
        # The same op in a concurrent push won the race: replay its result.
        stored = AppliedOp.objects.filter(user=user, op_id=op.op_id).first()
        if stored is None:
            raise
        return stored.result
    return result


def _apply_and_describe(user, op):
    raw = {"opId": str(op.op_id), "entity": op.entity, "entityId": op.entity_id}
    try:
        status, state = _apply(user, op)
    except Rejected as e:
        return _result(raw, REJECTED, reason=e.reason, field=e.field, state=e.state)
    return _result(raw, status, state=state)


def _result(raw, status, reason=None, field=None, state=None):
    result = {
        "opId": raw.get("opId"),
        "entity": raw.get("entity"),
        "entityId": raw.get("entityId"),
        "status": status,
        "state": state,
    }
    if reason:
        result["reason"] = reason
    if field:
        result["field"] = field
    return result


def _parse(raw, device_id):
    if not isinstance(raw, dict):
        raise Rejected("invalid_op")
    try:
        op_id = uuid.UUID(str(raw.get("opId")))
    except ValueError:
        raise Rejected("invalid_op", "opId") from None
    entity_id = raw.get("entityId")
    if not isinstance(entity_id, str) or not ENTITY_ID.match(entity_id):
        raise Rejected("invalid_op", "entityId")
    op_type = raw.get("opType")
    if op_type not in OP_TYPES:
        raise Rejected("invalid_op", "opType")
    base = raw.get("baseVersion")
    if isinstance(base, bool) or not isinstance(base, int) or base < 0:
        raise Rejected("invalid_op", "baseVersion")
    changed = raw.get("changedFields", {})
    if not isinstance(changed, dict):
        raise Rejected("invalid_op", "changedFields")
    entity = raw.get("entity")
    if not isinstance(entity, str):
        raise Rejected("invalid_op", "entity")
    return Op(op_id, device_id, entity, entity_id, op_type, base, changed)


# --- Applying one op ---


def _apply(user, op):
    spec = ENTITIES.get(op.entity)
    if spec is None:
        raise Rejected("unknown_entity")

    row, group = _find(user, spec, op)
    incoming = _clean(spec, op, row)
    ctx = Context(user=user, row_id=op.entity_id, group=group, changed=frozenset(incoming))

    if op.op_type == "delete":
        return _delete(user, spec, op, row, group)
    if spec.insert_only:
        return _insert_only(user, spec, op, row, incoming, ctx)
    if op.op_type == "create" and row is None:
        return _create(user, spec, op, incoming, ctx)
    if op.op_type == "create" and row.deleted:
        return _restore(user, spec, op, row, incoming, ctx)
    # An update, or a create for an id that already exists (e.g. two devices
    # setting the same month's budget, ADR 0002): a field-level update.
    return _update(user, spec, op, row, incoming, ctx)


def _find(user, spec, op):
    """The row (or None) and its group, after the permission check."""
    if spec.scope != GROUP:
        row = spec.model.objects.filter(owner=user, entity_id=op.entity_id).first()
        return row, None

    row = spec.model.objects.filter(entity_id=op.entity_id).select_related("group").first()
    if row is not None:
        group = row.group
    else:
        group_id = op.changed.get("groupId")
        group = Group.objects.filter(entity_id=group_id).first() if isinstance(group_id, str) else None
        if group is None:
            # Don't reveal whether the group exists.
            raise Rejected("not_a_member" if op.op_type == "create" else "not_found")
    if group.deleted or not Member.objects.filter(group=group, user=user, deleted=False).exists():
        raise Rejected("not_a_member")
    return row, group


def _clean(spec, op, row):
    """Checks every field in the op and returns them as Python values."""
    if op.op_type == "delete":
        return {}
    cleaned = {}
    for name, value in op.changed.items():
        if name == "id":
            if value != op.entity_id:
                raise Rejected("invalid_field", "id")
            continue
        f = spec.fields.get(name)
        if f is None or name in SYNC_METADATA:
            raise Rejected("unknown_field", name)
        try:
            cleaned[name] = f.clean(value)
        except ValueError:
            raise Rejected("invalid_field", name) from None
    if op.op_type == "update" or row is not None:
        for name in cleaned:
            if spec.fields[name].immutable:
                current = spec.read(row)[name] if row is not None else None
                if current is not None and cleaned[name] != current:
                    raise Rejected("immutable_field", name)
    return cleaned


def _check(spec, values, ctx):
    try:
        spec.check(values, ctx)
    except RowInvalid as e:
        raise Rejected(e.reason, e.field) from None


def _require_all(spec, values):
    for name, f in spec.fields.items():
        if name not in values:
            if f.required:
                raise Rejected("missing_field", name)
            values[name] = None
    return values


def _new_row(user, spec, op, ctx):
    row = spec.model(entity_id=op.entity_id)
    if spec.scope != GROUP:
        row.owner = user
    else:
        row.group = ctx.group
    return row


def _create(user, spec, op, incoming, ctx):
    values = _require_all(spec, dict(incoming))
    _check(spec, values, ctx)
    row = _new_row(user, spec, op, ctx)
    spec.write(row, values, ctx)
    row.updated_by = user
    row.save()
    _history(user, spec, op, row, ctx, EntityHistory.Kind.CREATED)
    return APPLIED, spec.state(row)


def _restore(user, spec, op, row, incoming, ctx):
    """A create for a deleted id brings it back with the op's values."""
    values = {**spec.read(row), **incoming}
    _check(spec, values, ctx)
    spec.write(row, values, ctx)
    row.deleted = False
    row.updated_by = user
    row.save()
    _history(user, spec, op, row, ctx, EntityHistory.Kind.RESTORED)
    return APPLIED, spec.state(row)


def _insert_only(user, spec, op, row, incoming, ctx):
    if op.op_type == "update":
        raise Rejected("insert_only", state=spec.state(row) if row else None)
    if row is not None:
        # Settlement ids are client UUIDs: the same id again is a re-send.
        values = _require_all(spec, dict(incoming))
        if spec.read(row) == values:
            return APPLIED, spec.state(row)
        raise Rejected("already_exists", state=spec.state(row))
    return _create(user, spec, op, incoming, ctx)


def _update(user, spec, op, row, incoming, ctx):
    if row is None:
        built_in = spec.built_ins.get(op.entity_id)
        if built_in is None:
            raise Rejected("not_found")
        # A built-in category exists implicitly at version 0 (ADR 0001).
        current, version = {name: spec.fields[name].clean(v) for name, v in built_in.items()}, 0
    else:
        current, version = spec.read(row), row.version

    if row is not None and row.deleted:
        # Delete wins (§6). Keep the edit in history so it isn't lost silently.
        for name, value in incoming.items():
            _history(
                user, spec, op, row, ctx, EntityHistory.Kind.DISCARDED,
                field=name, old=current.get(name), new=value,
            )
        raise Rejected("deleted", state=spec.state(row))

    if op.base_version > version:
        raise Rejected("bad_base_version", state=spec.state(row) if row else None)

    concurrent, others = _concurrent(spec, op, ctx) if op.base_version < version else (set(), False)
    changes = {name: value for name, value in incoming.items() if current.get(name) != value}
    values = {**current, **incoming}
    _check(spec, values, ctx)

    status = MERGED if others else APPLIED
    if not changes:
        return status, spec.state(row) if row else None

    if row is None:
        row = _new_row(user, spec, op, ctx)
        spec.write(row, values, ctx)
    else:
        spec.write(row, changes, ctx)
    row.updated_by = user
    row.save()

    for name, value in changes.items():
        # Same field changed concurrently: this op arrived later and wins;
        # the value it replaces is the loser, kept as `overwritten`.
        kind = EntityHistory.Kind.OVERWRITTEN if name in concurrent else EntityHistory.Kind.CHANGED
        _history(user, spec, op, row, ctx, kind, field=name, old=current.get(name), new=value)
    return status, spec.state(row)


def _delete(user, spec, op, row, group):
    if spec.insert_only:
        raise Rejected("insert_only", state=spec.state(row) if row else None)
    if not spec.deletable:
        raise Rejected("not_deletable", state=spec.state(row) if row else None)
    if row is None:
        raise Rejected("not_found")
    if op.base_version > row.version:
        raise Rejected("bad_base_version", state=spec.state(row))
    if row.deleted:
        return APPLIED, spec.state(row)
    ctx = Context(user=user, row_id=op.entity_id, group=group)
    # Delete wins over any concurrent edit; "merged" just says there was one.
    _, others = _concurrent(spec, op, ctx) if op.base_version < row.version else (set(), False)
    status = MERGED if others else APPLIED
    row.deleted = True
    row.updated_by = user
    row.save()
    _history(user, spec, op, row, ctx, EntityHistory.Kind.DELETED)
    return status, spec.state(row)


def _concurrent(spec, op, ctx):
    """What other devices did to this row after the op's baseVersion: the
    fields they changed, and whether they did anything at all."""
    rows = list(
        _history_scope(spec, ctx)
        .filter(entity=spec.name, entity_id=op.entity_id, version__gt=op.base_version)
        .exclude(device_id=op.device_id)
        .values_list("kind", "field")
    )
    field_kinds = {EntityHistory.Kind.CHANGED, EntityHistory.Kind.OVERWRITTEN}
    whole_row_kinds = {EntityHistory.Kind.CREATED, EntityHistory.Kind.RESTORED}
    fields = {field for kind, field in rows if kind in field_kinds}
    if any(kind in whole_row_kinds for kind, _ in rows):
        # A create or restore set every field (e.g. the same month's budget
        # created on two devices, ADR 0002).
        fields |= set(spec.fields)
    return fields, bool(rows)


def _history_scope(spec, ctx):
    if spec.scope == GROUP:
        return EntityHistory.objects.filter(group=ctx.group)
    return EntityHistory.objects.filter(owner=ctx.user)


def _history(user, spec, op, row, ctx, kind, field="", old=None, new=None):
    f = spec.fields.get(field)
    EntityHistory.objects.create(
        entity=spec.name,
        entity_id=op.entity_id,
        owner=None if spec.scope == GROUP else user,
        group=ctx.group if spec.scope == GROUP else None,
        kind=kind,
        field=field,
        old_value=f.dump(old) if f else None,
        new_value=f.dump(new) if f else None,
        changed_by=user,
        op_id=op.op_id,
        device_id=op.device_id,
        version=row.version,
    )
