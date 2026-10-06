"""One test per row of the conflict policy (ARCHITECTURE.md §6).

Two devices of the same user ("phone" and "laptop") both start from version 1
of an expense, then edit it without seeing each other's change.
"""

import uuid

import pytest

from groups.models import Member
from ledger.models import Expense
from sync.models import EntityHistory

from . import ledger_factories as make
from .sync_helpers import DAY, Device, create_expense, op

pytestmark = pytest.mark.django_db


@pytest.fixture
def phone(user):
    return Device(user)


@pytest.fixture
def laptop(user):
    return Device(user)


@pytest.fixture
def expense_id(phone):
    result = create_expense(phone, amountMinor=120_000)
    assert result["state"]["version"] == 1
    return result["entityId"]


def stored(entity_id):
    return Expense.objects.get(entity_id=entity_id)


def history(entity_id, kind):
    return list(EntityHistory.objects.filter(entity_id=entity_id, kind=kind))


# --- Row 1: two edits change different fields → merge both ---


def test_different_fields_are_merged(phone, laptop, expense_id):
    first = phone.one(op("expenses", expense_id, base=1, amountMinor=150_000))
    second = laptop.one(op("expenses", expense_id, base=1, note="rent share"))

    assert first["status"] == "applied"
    assert second["status"] == "merged"
    row = stored(expense_id)
    assert (row.amount_minor, row.note, row.version) == (150_000, "rent share", 3)
    assert second["state"]["amountMinor"] == 150_000
    assert second["state"]["note"] == "rent share"
    assert history(expense_id, "overwritten") == []


# --- Row 2: same field → the later one (server receive order) wins; the loser is kept in history ---


def test_same_field_later_wins_and_the_loser_is_in_history(phone, laptop, expense_id, user):
    phone.one(op("expenses", expense_id, base=1, amountMinor=150_000))
    result = laptop.one(op("expenses", expense_id, base=1, amountMinor=200_000))

    assert result["status"] == "merged"
    assert stored(expense_id).amount_minor == 200_000
    (lost,) = history(expense_id, "overwritten")
    assert (lost.field, lost.old_value, lost.new_value) == ("amountMinor", 150_000, 200_000)
    assert lost.changed_by == user
    assert lost.device_id == laptop.id


def test_a_devices_own_earlier_ops_are_not_conflicts(phone, expense_id):
    """The app keeps its local version until it pulls, so a device's ops
    share a baseVersion. They are sequential, not concurrent."""
    results = phone.push(
        op("expenses", expense_id, base=1, amountMinor=130_000),
        op("expenses", expense_id, base=1, amountMinor=140_000),
        op("expenses", expense_id, base=1, note="edited twice"),
    )

    assert [r["status"] for r in results] == ["applied"] * 3
    assert stored(expense_id).amount_minor == 140_000
    assert history(expense_id, "overwritten") == []


def test_create_then_edit_before_any_pull(phone):
    entity_id = str(uuid.uuid4())
    results = phone.push(
        op("expenses", entity_id, "create", 0, **{"id": entity_id, "amountMinor": 4500, "currency": "TND",
                                                   "categoryId": "food", "date": DAY, "note": None, "source": "manual"}),
        op("expenses", entity_id, base=0, amountMinor=5000),
    )

    assert [r["status"] for r in results] == ["applied", "applied"]
    assert stored(entity_id).amount_minor == 5000


# --- Row 3: edit vs delete → delete wins (restorable) ---


def test_an_edit_after_a_delete_is_rejected_and_kept_in_history(phone, laptop, expense_id):
    deleted = phone.one(op("expenses", expense_id, "delete", 1))
    edit = laptop.one(op("expenses", expense_id, base=1, amountMinor=999_000))

    assert deleted["status"] == "applied"
    assert edit["status"] == "rejected"
    assert edit["reason"] == "deleted"
    assert edit["state"]["deleted"] is True
    row = stored(expense_id)
    assert row.deleted and row.amount_minor == 120_000
    (discarded,) = history(expense_id, "discarded")
    assert (discarded.field, discarded.new_value) == ("amountMinor", 999_000)


def test_a_delete_after_a_concurrent_edit_still_deletes(phone, laptop, expense_id):
    phone.one(op("expenses", expense_id, base=1, amountMinor=150_000))
    result = laptop.one(op("expenses", expense_id, "delete", 1))

    assert result["status"] == "merged"
    assert result["state"]["deleted"] is True
    assert stored(expense_id).deleted
    assert len(history(expense_id, "deleted")) == 1


def test_a_deleted_expense_can_be_restored(phone, expense_id):
    phone.one(op("expenses", expense_id, "delete", 1))

    result = create_expense(phone, expense_id, amountMinor=120_000, note="restored")

    assert result["status"] == "applied"
    assert result["state"]["deleted"] is False
    assert stored(expense_id).note == "restored"
    assert len(history(expense_id, "restored")) == 1


def test_deleting_twice_is_harmless(phone, laptop, expense_id):
    phone.one(op("expenses", expense_id, "delete", 1))
    again = laptop.one(op("expenses", expense_id, "delete", 1))

    assert again["status"] == "applied"
    assert stored(expense_id).version == 2


# --- Row 4: settlements are insert-only ---


@pytest.fixture
def flat(user):
    from accounts.models import User

    ali_user = User.objects.create_user(email="ali@example.com", password="x-long-password")
    g = make.group(user)
    return g, make.member(g, user, "Sami"), make.member(g, ali_user, "Ali")


def settlement_op(g, payer, payee, entity_id=None, amount=30_000, reverses=None, op_type="create", base=0, **extra):
    entity_id = entity_id or str(uuid.uuid4())
    fields = {
        "id": entity_id,
        "groupId": g.entity_id,
        "fromMemberId": payer.entity_id,
        "toMemberId": payee.entity_id,
        "amountMinor": amount,
        "currency": "TND",
        "date": DAY,
        "reversesId": reverses,
        **extra,
    }
    if op_type != "create":
        fields = extra
    return op("settlements", entity_id, op_type, base, **fields)


def test_settlements_cannot_be_edited_or_deleted(phone, flat):
    g, sami, ali = flat
    created = phone.one(settlement_op(g, ali, sami))
    sid = created["entityId"]

    edit = phone.one(settlement_op(g, ali, sami, sid, op_type="update", base=1, amountMinor=1))
    delete = phone.one(settlement_op(g, ali, sami, sid, op_type="delete", base=1))

    assert created["status"] == "applied"
    assert (edit["status"], edit["reason"]) == ("rejected", "insert_only")
    assert (delete["status"], delete["reason"]) == ("rejected", "insert_only")
    assert edit["state"]["amountMinor"] == 30_000


def test_a_mistake_is_fixed_with_a_mirror_reversal_once(phone, flat):
    g, sami, ali = flat
    original = phone.one(settlement_op(g, ali, sami))["entityId"]

    wrong_way = phone.one(settlement_op(g, ali, sami, reverses=original))
    wrong_amount = phone.one(settlement_op(g, sami, ali, amount=1, reverses=original))
    reversal = phone.one(settlement_op(g, sami, ali, reverses=original))
    twice = phone.one(settlement_op(g, sami, ali, reverses=original))

    assert wrong_way["reason"] == "not_a_mirror"
    assert wrong_amount["reason"] == "not_a_mirror"
    assert reversal["status"] == "applied"
    assert reversal["state"]["reversesId"] == original
    assert twice["reason"] == "already_reversed"


def test_resending_a_settlement_is_fine_but_reusing_its_id_is_not(phone, laptop, flat):
    g, sami, ali = flat
    sid = str(uuid.uuid4())
    phone.one(settlement_op(g, ali, sami, sid))

    same = laptop.one(settlement_op(g, ali, sami, sid))
    different = laptop.one(settlement_op(g, ali, sami, sid, amount=1))

    assert same["status"] == "applied"
    assert (different["status"], different["reason"]) == ("rejected", "already_exists")


# --- Row 5: a member removed from a group → their pending ops are rejected ---


def test_a_removed_members_pending_ops_are_rejected(user, phone, flat):
    g, sami, ali = flat
    expense_id = str(uuid.uuid4())
    shares = {sami.entity_id: 3000, ali.entity_id: 3000}
    create = {
        "id": expense_id, "groupId": g.entity_id, "payerId": sami.entity_id, "amountMinor": 6000,
        "currency": "TND", "date": DAY, "split": {"type": "equal"}, "shares": shares, "categoryId": None,
    }
    assert phone.one(op("shared_expenses", expense_id, "create", 0, **create))["status"] == "applied"

    Member.objects.filter(pk=sami.pk).update(deleted=True)  # Removed while the phone was offline.
    new_id = str(uuid.uuid4())
    results = phone.push(
        op("shared_expenses", expense_id, base=1, categoryId="food"),
        op("shared_expenses", new_id, "create", 0, **{**create, "id": new_id}),
        settlement_op(g, sami, ali),
    )

    for result in results:
        assert (result["status"], result["reason"]) == ("rejected", "not_a_member")
        assert result["state"] is None, "no data for non-members"


@pytest.mark.django_db(transaction=True)
def test_simultaneous_same_field_edits_still_leave_one_loser_in_history(user):
    """Without the ledger lock both ops could read version 1, both look
    "applied", and the overwritten value would vanish from history."""
    import threading

    from django.db import connection

    devices = [Device(user) for _ in range(2)]
    expense_id = create_expense(devices[0], amountMinor=120_000)["entityId"]
    start = threading.Barrier(2)
    results, errors = [], []

    def send(device, amount):
        try:
            start.wait(5)
            results.append(device.one(op("expenses", expense_id, base=1, amountMinor=amount)))
        except Exception as e:  # noqa: BLE001 - surfaced by the assert below
            errors.append(e)
        finally:
            connection.close()

    threads = [threading.Thread(target=send, args=(d, a)) for d, a in zip(devices, (150_000, 200_000))]
    for t in threads:
        t.start()
    for t in threads:
        t.join(20)

    assert not errors
    assert sorted(r["status"] for r in results) == ["applied", "merged"]
    winner = next(r for r in results if r["status"] == "merged")["state"]["amountMinor"]
    assert stored(expense_id).amount_minor == winner
    (lost,) = history(expense_id, "overwritten")
    assert lost.new_value == winner
