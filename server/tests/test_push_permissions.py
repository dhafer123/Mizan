"""Who may change what: own personal rows, and groups you're an active member of."""

import uuid

import pytest

from accounts.models import User
from ledger.models import Expense

from . import ledger_factories as make
from .sync_helpers import DAY, Device, create_expense, op

pytestmark = pytest.mark.django_db


@pytest.fixture
def ali(db):
    return User.objects.create_user(email="ali@example.com", password="x-long-password")


def test_push_needs_a_signed_in_user(client):
    response = client.post("/sync/push", {"deviceId": str(uuid.uuid4()), "ops": []}, format="json")

    assert response.status_code == 401


def test_nobody_can_edit_or_delete_someone_elses_personal_row(user, ali):
    expense_id = create_expense(Device(user), amountMinor=4500)["entityId"]
    intruder = Device(ali)

    edit = intruder.one(op("expenses", expense_id, base=1, amountMinor=1))
    delete = intruder.one(op("expenses", expense_id, "delete", 1))

    # Personal rows are looked up among the sender's own: to Ali it doesn't exist.
    assert (edit["reason"], delete["reason"]) == ("not_found", "not_found")
    assert edit["state"] is None
    row = Expense.objects.get(owner=user, entity_id=expense_id)
    assert (row.amount_minor, row.deleted) == (4500, False)


def test_the_same_id_for_two_users_is_two_rows(user, ali):
    create_expense(Device(user), "same-id", note="Sami's")
    create_expense(Device(ali), "same-id", note="Ali's")

    assert Expense.objects.get(owner=user).note == "Sami's"
    assert Expense.objects.get(owner=ali).note == "Ali's"


@pytest.fixture
def flat(user, ali):
    g = make.group(user)
    return g, make.member(g, user, "Sami"), make.member(g, ali, "Ali")


def shared_create(g, payer, shares, entity_id=None, **overrides):
    entity_id = entity_id or str(uuid.uuid4())
    fields = {
        "id": entity_id,
        "groupId": g.entity_id,
        "payerId": payer.entity_id,
        "amountMinor": sum(shares.values()),
        "currency": g.currency,
        "date": DAY,
        "split": {"type": "exact", "amounts": shares},
        "shares": shares,
        "categoryId": None,
        **overrides,
    }
    return op("shared_expenses", entity_id, "create", 0, **fields)


def test_outsiders_cannot_touch_a_group(user, flat, django_user_model):
    g, sami, ali = flat
    nour = Device(django_user_model.objects.create_user(email="nour@example.com", password="x-long-password"))
    existing = Device(user).one(shared_create(g, sami, {sami.entity_id: 3000, ali.entity_id: 3000}))["entityId"]

    results = nour.push(
        shared_create(g, sami, {sami.entity_id: 6000}),
        op("shared_expenses", existing, base=1, categoryId="food"),
        op("shared_expenses", existing, "delete", 1),
    )

    for result in results:
        assert (result["status"], result["reason"], result["state"]) == ("rejected", "not_a_member", None)


def test_a_group_that_doesnt_exist_looks_like_one_youre_not_in(user):
    result = Device(user).one(
        op("shared_expenses", str(uuid.uuid4()), "create", 0, groupId=str(uuid.uuid4()))
    )

    assert result["reason"] == "not_a_member"


def test_members_of_another_group_cannot_be_payers_or_sharers(user, flat):
    g, sami, ali = flat
    other = make.group(user)
    stranger = make.member(other, name="Stranger")
    phone = Device(user)

    as_payer = phone.one(shared_create(g, stranger, {sami.entity_id: 6000}))
    as_sharer = phone.one(shared_create(g, sami, {stranger.entity_id: 6000}))

    assert (as_payer["reason"], as_payer["field"]) == ("unknown_member", "payerId")
    assert (as_sharer["reason"], as_sharer["field"]) == ("unknown_member", "shares")


def test_a_shared_expense_cannot_move_to_another_group(user, flat):
    g, sami, ali = flat
    other = make.group(user)
    make.member(other, user, "Sami")
    phone = Device(user)
    expense_id = phone.one(shared_create(g, sami, {sami.entity_id: 6000}))["entityId"]

    result = phone.one(op("shared_expenses", expense_id, base=1, groupId=other.entity_id))

    assert (result["reason"], result["field"]) == ("immutable_field", "groupId")
