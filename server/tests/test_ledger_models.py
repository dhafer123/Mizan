"""Keys, constraints and insert-only rules on the ledger, groups and sync tables."""

import datetime
import uuid

import pytest
from django.db import IntegrityError, transaction

from accounts.models import User
from ledger.models import Budget, Category, Settlement
from sync.models import AppliedOp, EntityHistory

from . import ledger_factories as make

pytestmark = pytest.mark.django_db


@pytest.fixture
def ali(db):
    return User.objects.create_user(email="ali@example.com", password="x-long-password")


def refused(fn):
    """The database refuses the write (and the test transaction stays usable)."""
    with pytest.raises(IntegrityError), transaction.atomic():
        fn()


# --- Personal rows: keyed by (owner, entity_id) ---


def test_every_user_can_have_food_and_the_same_month_budget(user, ali):
    make.category(user, "food")
    make.category(ali, "food")
    make.budget(user, "2026-10")
    make.budget(ali, "2026-10")

    assert Category.objects.filter(entity_id="food").count() == 2
    assert Budget.objects.filter(entity_id="budget-2026-10").count() == 2


def test_one_row_per_owner_and_id(user):
    make.category(user, "food")
    refused(lambda: make.category(user, "food", name="Food again"))
    make.budget(user, "2026-10")
    refused(lambda: make.budget(user, "2026-10"))


def test_deleted_is_a_tombstone_flag(user):
    row = make.expense(user)
    row.deleted = True
    row.save()

    assert row.version == 2
    assert row.deleted


@pytest.mark.parametrize(
    "build",
    [
        lambda u: make.expense(u, amount_minor=0),
        lambda u: make.expense(u, amount_minor=-4500),
        lambda u: make.expense(u, currency="tnd"),
        lambda u: make.expense(u, source="fax"),
        lambda u: make.category(u, monthly_limit_minor=0),
        lambda u: make.budget(u, "2026-13"),
        lambda u: make.budget(u, "26-10"),
        lambda u: make.budget(u, total_limit_minor=-1),
        lambda u: make.income(u, amount_minor=0),
        lambda u: make.income(u, day_of_month=32),
        lambda u: make.income(u, day_of_month=None),
        lambda u: make.income(u, schedule_type="oneOff", day_of_month=None, date=None),
        lambda u: make.income(u, schedule_type="oneOff", day_of_month=5, date=make.DAY),
        lambda u: make.income(u, schedule_type="irregular", day_of_month=5),
    ],
    ids=[
        "expense zero",
        "expense negative",
        "lowercase currency",
        "unknown source",
        "category zero limit",
        "month 13",
        "short month",
        "negative budget",
        "income zero",
        "day 32",
        "monthly without day",
        "one-off without date",
        "one-off with a day",
        "irregular with a day",
    ],
)
def test_impossible_rows_are_refused(user, build):
    refused(lambda: build(user))


def test_valid_schedules(user):
    make.income(user)
    make.income(user, schedule_type="oneOff", day_of_month=None, date=datetime.date(2026, 11, 1))
    make.income(user, schedule_type="irregular", day_of_month=None)


# --- Groups and members ---


def test_a_user_is_in_a_group_once_but_can_rejoin_after_removal(user):
    g = make.group(user)
    first = make.member(g, user)
    refused(lambda: make.member(g, user, name="Sami again"))

    first.deleted = True
    first.save()
    make.member(g, user, name="Sami, back")


def test_placeholders_have_no_user(user):
    g = make.group(user)
    make.member(g, name="Ali (placeholder)")
    make.member(g, name="Nour (placeholder)")

    assert g.members.filter(user__isnull=True).count() == 2


def test_group_side_ids_are_unique_across_the_server(user):
    g = make.group(user)
    refused(lambda: make.group(user, entity_id=g.entity_id))


# --- Settlements: insert-only ---


@pytest.fixture
def pair(user):
    g = make.group(user)
    return g, make.member(g, user, "Sami"), make.member(g, name="Ali")


def test_settlements_cannot_be_edited(pair):
    g, sami, ali = pair
    s = make.settlement(g, ali, sami)
    assert s.version == 1

    def edit():
        s.amount_minor = 1
        s.save()

    refused(edit)
    refused(lambda: Settlement.objects.filter(pk=s.pk).update(amount_minor=1))
    assert Settlement.objects.get(pk=s.pk).amount_minor == 10_000


def test_a_mistake_is_undone_by_a_reversal_once(pair):
    g, sami, ali = pair
    original = make.settlement(g, ali, sami)

    make.settlement(g, sami, ali, reverses=original)

    assert original.reversed_by.from_member == sami
    refused(lambda: make.settlement(g, sami, ali, reverses=original))


def test_settlement_rules(pair):
    g, sami, ali = pair
    refused(lambda: make.settlement(g, sami, sami))
    refused(lambda: make.settlement(g, ali, sami, amount_minor=0))
    refused(lambda: make.settlement(g, ali, sami, deleted=True))


def test_shared_expense_amount_positive(pair):
    g, sami, ali = pair
    refused(lambda: make.shared_expense(g, sami, {sami.entity_id: 0}))


# --- History and the applied-op log ---


def test_history_is_insert_only_and_sequenced(user):
    before = make.expense(user).server_seq
    h = make.history(owner=user, old_value=120_000, new_value=150_000)

    assert h.server_seq > before

    def edit():
        h.new_value = 1
        h.save()

    refused(edit)


def test_history_has_exactly_one_scope(user):
    g = make.group(user)
    make.history(group=g, entity="shared_expenses")
    refused(lambda: make.history())
    refused(lambda: make.history(owner=user, group=g))


def test_history_keeps_any_json_value(user):
    for value in (None, 0, "Food", {"type": "equal"}, [1, 2]):
        make.history(owner=user, old_value=value)
    assert EntityHistory.objects.count() == 5


def test_an_op_id_is_recorded_once_per_user(user, ali):
    op_id = uuid.uuid4()
    make.applied_op(user, op_id)

    refused(lambda: make.applied_op(user, op_id))
    # Another user's op with the same id is a different op: it can't read ours.
    make.applied_op(ali, op_id)
    assert AppliedOp.objects.filter(op_id=op_id).count() == 2


def test_applied_ops_are_insert_only(user):
    op = make.applied_op(user)
    refused(lambda: AppliedOp.objects.filter(pk=op.pk).update(status="rejected", reason="x"))


def test_a_reason_only_comes_with_a_rejection(user):
    make.applied_op(user, status="rejected", reason="not_a_member")
    refused(lambda: make.applied_op(user, status="applied", reason="not_a_member"))
