"""Pushing the same op again changes nothing and returns the same result."""

import threading
import uuid

import pytest
from django.db import connection

from ledger.models import Expense
from sync.models import AppliedOp, EntityHistory

from .sync_helpers import Device, create_expense, expense_fields, op


@pytest.mark.django_db
def test_the_same_op_twice_changes_nothing(user):
    phone = Device(user)
    expense_id = create_expense(phone)["entityId"]
    edit = op("expenses", expense_id, base=1, amountMinor=5000)

    first = phone.one(edit)
    state = Expense.objects.get(entity_id=expense_id)
    history_count = EntityHistory.objects.count()
    again = phone.one(edit)

    assert again == first
    after = Expense.objects.get(entity_id=expense_id)
    assert (after.version, after.server_seq) == (state.version, state.server_seq)
    assert EntityHistory.objects.count() == history_count
    assert AppliedOp.objects.filter(op_id=edit["opId"]).count() == 1


@pytest.mark.django_db
def test_a_retry_from_another_device_of_the_same_user_is_the_same_op(user):
    phone, laptop = Device(user), Device(user)
    create = op("expenses", "e-1", "create", 0, **expense_fields("e-1"))

    assert phone.one(create) == laptop.one(create)
    assert Expense.objects.count() == 1


@pytest.mark.django_db
def test_a_rejected_op_is_rejected_the_same_way_again(user):
    phone = Device(user)
    bad = op("expenses", "nope", base=1, amountMinor=5000)

    first = phone.one(bad)
    create_expense(phone, "nope")  # Exists now, but the op id already has its answer.
    again = phone.one(bad)

    assert first["reason"] == "not_found"
    assert again == first


@pytest.mark.django_db
def test_the_same_op_in_one_batch_is_applied_once(user):
    phone = Device(user)
    expense_id = create_expense(phone)["entityId"]
    edit = op("expenses", expense_id, base=1, amountMinor=5000)

    first, second = phone.push(edit, edit)

    assert first == second
    assert Expense.objects.get(entity_id=expense_id).version == 2


@pytest.mark.django_db
def test_another_users_op_id_is_a_different_op(user, django_user_model):
    """Op ids are per user: reusing one never reads back someone else's result."""
    ali = django_user_model.objects.create_user(email="ali@example.com", password="x-long-password")
    op_id = uuid.uuid4()

    mine = Device(user).one(op("expenses", "e-1", "create", 0, op_id=op_id, **expense_fields("e-1", note="mine")))
    theirs = Device(ali).one(op("expenses", "e-1", "create", 0, op_id=op_id, **expense_fields("e-1", note="theirs")))

    assert mine["state"]["note"] == "mine"
    assert theirs["state"]["note"] == "theirs"
    assert Expense.objects.count() == 2


@pytest.mark.django_db(transaction=True)
def test_the_same_op_pushed_twice_at_once_is_applied_once(user):
    """Two pushes race with one op (e.g. a timeout and a retry): the ledger
    lock makes the second wait, and the applied-op log turns it into a replay."""
    expense_id = "race-1"
    create_expense(Device(user), expense_id)
    edit = op("expenses", expense_id, base=1, amountMinor=7000)
    results, errors = [], []

    def send():
        try:
            results.append(Device(user).one(edit))
        except Exception as e:  # noqa: BLE001 - surfaced by the assert below
            errors.append(e)
        finally:
            connection.close()

    threads = [threading.Thread(target=send) for _ in range(4)]
    for t in threads:
        t.start()
    for t in threads:
        t.join(20)

    assert not errors
    assert len(results) == 4
    assert all(r == results[0] for r in results)
    assert Expense.objects.get(entity_id=expense_id).version == 2
    assert AppliedOp.objects.filter(op_id=edit["opId"]).count() == 1
