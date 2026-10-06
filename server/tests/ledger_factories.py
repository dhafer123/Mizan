"""Small builders for ledger rows in tests. Each takes overrides as kwargs."""

import datetime
import uuid

from groups.models import Group, Member
from ledger.models import Budget, Category, Expense, IncomeSource, SharedExpense, Settlement
from sync.models import AppliedOp, EntityHistory

DAY = datetime.date(2026, 10, 6)


def uid():
    return str(uuid.uuid4())


def expense(owner, entity_id=None, **kw):
    fields = {"amount_minor": 4500, "currency": "TND", "category_id": "food", "date": DAY, **kw}
    return Expense.objects.create(owner=owner, entity_id=entity_id or uid(), **fields)


def category(owner, entity_id="food", **kw):
    fields = {"name": "Food", "icon": "restaurant", "currency": "TND", **kw}
    return Category.objects.create(owner=owner, entity_id=entity_id, **fields)


def income(owner, entity_id=None, **kw):
    fields = {
        "name": "Scholarship",
        "amount_minor": 250_000,
        "currency": "TND",
        "schedule_type": "monthly",
        "day_of_month": 5,
        **kw,
    }
    return IncomeSource.objects.create(owner=owner, entity_id=entity_id or uid(), **fields)


def budget(owner, month="2026-10", **kw):
    fields = {"total_limit_minor": 600_000, "currency": "TND", **kw}
    return Budget.objects.create(owner=owner, entity_id=f"budget-{month}", month=month, **fields)


def group(creator, entity_id=None, **kw):
    fields = {"name": "Flat 4B", "currency": "TND", **kw}
    return Group.objects.create(entity_id=entity_id or uid(), created_by=creator, **fields)


def member(group, user=None, name="Sami", **kw):
    return Member.objects.create(entity_id=uid(), group=group, user=user, display_name=name, **kw)


def shared_expense(group, payer, shares, **kw):
    fields = {
        "amount_minor": sum(shares.values()),
        "currency": group.currency,
        "date": DAY,
        "split": {"type": "exact", "amounts": shares},
        "shares": shares,
        **kw,
    }
    return SharedExpense.objects.create(entity_id=uid(), group=group, payer=payer, **fields)


def settlement(group, from_member, to_member, amount_minor=10_000, **kw):
    return Settlement.objects.create(
        entity_id=uid(),
        group=group,
        from_member=from_member,
        to_member=to_member,
        amount_minor=amount_minor,
        currency=group.currency,
        date=DAY,
        **kw,
    )


def history(owner=None, group=None, **kw):
    fields = {"entity": "expenses", "entity_id": uid(), "kind": "changed", "field": "amountMinor", **kw}
    return EntityHistory.objects.create(owner=owner, group=group, **fields)


def applied_op(user, op_id=None, **kw):
    fields = {
        "entity": "expenses",
        "entity_id": uid(),
        "op_type": "create",
        "status": "applied",
        "result": {"status": "applied"},
        **kw,
    }
    return AppliedOp.objects.create(user=user, op_id=op_id or uuid.uuid4(), **fields)
