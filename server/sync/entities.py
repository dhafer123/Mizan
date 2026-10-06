"""What each synced entity looks like on the wire, and its rules.

The `entity` names and JSON field names are the app's (drift table names and
`toJson` keys). Each spec maps them to the ledger models, says which scope a
row lives in (one user, or one group), and checks a whole row before it is
written (`check`), since an update only carries the fields that changed.
"""

from dataclasses import dataclass, field
from typing import Callable

from groups.models import Group, Member
from ledger.models import Budget, Category, Expense, IncomeSource, Settlement, SharedExpense

from .fields import (
    BOOL,
    CHOICE,
    CURRENCY,
    DAY,
    DAY_OF_MONTH,
    JSON_OBJECT,
    MONTH_CODEC,
    OPTIONAL_DAY,
    OPTIONAL_POSITIVE_INT,
    OPTIONAL_REF,
    OPTIONAL_TEXT,
    POSITIVE_INT,
    REF,
    SHARES,
    TEXT,
    Field,
)

PERSONAL = "personal"
GROUP = "group"

# The currency a built-in category's row gets when first edited: the app's
# personal currency, fixed to TND until there is a setting (TASKS.md 2.2).
DEFAULT_CURRENCY = "TND"

# The built-in categories (ADR 0001). Must match the app's
# app/lib/features/expenses/domain/entities/default_categories.dart;
# tests/test_sync_entities.py checks that.
BUILT_IN_CATEGORIES = {
    entity_id: {"name": name, "icon": entity_id, "monthlyLimitMinor": None, "currency": DEFAULT_CURRENCY, "archived": False}
    for entity_id, name in [
        ("food", "Food"),
        ("transport", "Transport"),
        ("rent", "Rent"),
        ("study", "Study"),
        ("leisure", "Leisure"),
        ("other", "Other"),
    ]
}

SPLIT_TYPES = {"equal", "exact", "percentage", "shares"}


class RowInvalid(Exception):
    """A whole-row rule failed. `field` names the field to blame."""

    def __init__(self, reason, field=None):
        super().__init__(reason)
        self.reason = reason
        self.field = field


@dataclass
class Context:
    """What a row check needs beyond the values."""

    user: object
    row_id: str
    group: Group | None = None
    # JSON names of the fields this op sets.
    changed: frozenset = frozenset()
    _members: dict | None = None

    def members(self):
        """The group's members by entity id, removed ones included."""
        if self._members is None:
            self._members = {m.entity_id: m for m in Member.objects.filter(group=self.group)}
        return self._members

    def member(self, entity_id, field, active=True):
        member = self.members().get(entity_id)
        if member is None or (active and member.deleted):
            raise RowInvalid("unknown_member", field)
        return member


@dataclass
class EntitySpec:
    name: str
    model: type
    scope: str
    fields: dict
    check: Callable[[dict, Context], None] = lambda values, ctx: None
    insert_only: bool = False
    deletable: bool = True
    built_ins: dict = field(default_factory=dict)

    def read(self, row):
        """A row's values, keyed by JSON field name (Python values)."""
        values = {}
        for name, f in self.fields.items():
            value = getattr(row, f.attr)
            if f.ref or name == "groupId":
                value = value.entity_id if value is not None else None
            values[name] = value
        return values

    def write(self, row, values, ctx):
        """Sets `values` (JSON names, cleaned) on `row`, resolving references."""
        for name, value in values.items():
            f = self.fields[name]
            if name == "groupId":
                value = ctx.group
            elif f.ref == "member" and value is not None:
                value = ctx.members()[value]
            elif f.ref == "settlement" and value is not None:
                value = Settlement.objects.get(group=ctx.group, entity_id=value)
            setattr(row, f.attr, value)

    def dump(self, values):
        return {name: self.fields[name].dump(value) for name, value in values.items()}

    def state(self, row):
        """The row as the app stores it, sync metadata included."""
        return {
            "id": row.entity_id,
            **self.dump(self.read(row)),
            "version": row.version,
            "deleted": row.deleted,
            "updatedBy": str(row.updated_by_id) if row.updated_by_id else None,
            "serverSeq": row.server_seq,
        }


# --- Row checks ---


def _check_income(values, ctx):
    schedule = values["scheduleType"]
    day, date = values.get("dayOfMonth"), values.get("date")
    ok = {
        "monthly": day is not None and date is None,
        "oneOff": day is None and date is not None,
        "irregular": day is None and date is None,
    }[schedule]
    if not ok:
        raise RowInvalid("invalid_schedule", "scheduleType")


def _check_budget(values, ctx):
    # The id is derived from the month (ADR 0002).
    if ctx.row_id != f"budget-{values['month']}":
        raise RowInvalid("month_mismatch", "month")


def _check_group_currency(values, ctx):
    if values["currency"] != ctx.group.currency:
        raise RowInvalid("currency_mismatch", "currency")


def _check_shared_expense(values, ctx):
    _check_group_currency(values, ctx)
    changed = ctx.changed
    # New members must be active; old ones may have left since.
    ctx.member(values["payerId"], "payerId", active="payerId" in changed)
    for member_id in values["shares"]:
        ctx.member(member_id, "shares", active="shares" in changed)
    if sum(values["shares"].values()) != values["amountMinor"]:
        raise RowInvalid("shares_mismatch", "shares")
    if values["split"].get("type") not in SPLIT_TYPES:
        raise RowInvalid("invalid_split", "split")


def _check_settlement(values, ctx):
    _check_group_currency(values, ctx)
    payer = ctx.member(values["fromMemberId"], "fromMemberId")
    payee = ctx.member(values["toMemberId"], "toMemberId")
    if payer == payee:
        raise RowInvalid("same_member", "toMemberId")
    reverses_id = values.get("reversesId")
    if reverses_id is None:
        return
    original = Settlement.objects.filter(group=ctx.group, entity_id=reverses_id).first()
    if original is None:
        raise RowInvalid("unknown_settlement", "reversesId")
    # A reversal mirrors the original, so the two cancel out in every balance.
    mirrors = (
        original.from_member_id == payee.pk
        and original.to_member_id == payer.pk
        and original.amount_minor == values["amountMinor"]
    )
    if not mirrors:
        raise RowInvalid("not_a_mirror", "reversesId")
    if Settlement.objects.filter(reverses=original).exists():
        raise RowInvalid("already_reversed", "reversesId")


GROUP_ID = Field("group", REF, immutable=True)

ENTITIES = {
    spec.name: spec
    for spec in [
        EntitySpec(
            "expenses",
            Expense,
            PERSONAL,
            {
                "amountMinor": Field("amount_minor", POSITIVE_INT),
                "currency": Field("currency", CURRENCY),
                "categoryId": Field("category_id", REF),
                "date": Field("date", DAY),
                "note": Field("note", OPTIONAL_TEXT(200), required=False),
                "source": Field("source", CHOICE("manual", "voice", "receipt")),
            },
        ),
        EntitySpec(
            "categories",
            Category,
            PERSONAL,
            {
                "name": Field("name", TEXT(40)),
                "icon": Field("icon", TEXT(40)),
                "monthlyLimitMinor": Field("monthly_limit_minor", OPTIONAL_POSITIVE_INT, required=False),
                "currency": Field("currency", CURRENCY),
                "archived": Field("archived", BOOL),
            },
            # Categories are archived, never deleted (ADR 0001).
            deletable=False,
            built_ins=BUILT_IN_CATEGORIES,
        ),
        EntitySpec(
            "income_sources",
            IncomeSource,
            PERSONAL,
            {
                "name": Field("name", TEXT(60)),
                "amountMinor": Field("amount_minor", POSITIVE_INT),
                "currency": Field("currency", CURRENCY),
                "scheduleType": Field("schedule_type", CHOICE("monthly", "oneOff", "irregular")),
                "dayOfMonth": Field("day_of_month", DAY_OF_MONTH, required=False),
                "date": Field("date", OPTIONAL_DAY, required=False),
            },
            check=_check_income,
        ),
        EntitySpec(
            "budgets",
            Budget,
            PERSONAL,
            {
                "month": Field("month", MONTH_CODEC, immutable=True),
                "totalLimitMinor": Field("total_limit_minor", OPTIONAL_POSITIVE_INT, required=False),
                "currency": Field("currency", CURRENCY),
            },
            check=_check_budget,
        ),
        EntitySpec(
            "shared_expenses",
            SharedExpense,
            GROUP,
            {
                "groupId": GROUP_ID,
                "payerId": Field("payer", REF, ref="member"),
                "amountMinor": Field("amount_minor", POSITIVE_INT),
                "currency": Field("currency", CURRENCY),
                "date": Field("date", DAY),
                "split": Field("split", JSON_OBJECT),
                "shares": Field("shares", SHARES),
                "categoryId": Field("category_id", OPTIONAL_REF, required=False),
            },
            check=_check_shared_expense,
        ),
        EntitySpec(
            "settlements",
            Settlement,
            GROUP,
            {
                "groupId": GROUP_ID,
                "fromMemberId": Field("from_member", REF, ref="member"),
                "toMemberId": Field("to_member", REF, ref="member"),
                "amountMinor": Field("amount_minor", POSITIVE_INT),
                "currency": Field("currency", CURRENCY),
                "date": Field("date", DAY),
                "reversesId": Field("reverses", OPTIONAL_REF, required=False, ref="settlement"),
            },
            check=_check_settlement,
            insert_only=True,
            deletable=False,
        ),
    ]
}
