"""server_seq and version: set by the database on every write (sync/db.py)."""

import threading
import time

import pytest
from django.db import connection, transaction

from ledger.models import Expense

from . import ledger_factories as make

pytestmark = pytest.mark.django_db


def test_strictly_increasing_across_tables_and_writes(user):
    seqs = []

    def write(row):
        seqs.append(row.server_seq)
        return row

    e = write(make.expense(user))
    write(make.category(user))
    write(make.income(user))
    write(make.budget(user))
    g = write(make.group(user))
    sami = write(make.member(g, user))
    ali = write(make.member(g, name="Ali"))
    write(make.shared_expense(g, sami, {sami.entity_id: 3000, ali.entity_id: 3000}))
    write(make.settlement(g, ali, sami))
    write(make.history(owner=user))
    e.note = "edited"
    write(e.save() or e)

    assert all(isinstance(s, int) for s in seqs)
    assert seqs == sorted(seqs)
    assert len(set(seqs)) == len(seqs)


def test_every_update_takes_a_new_seq_and_bumps_the_version(user):
    row = make.expense(user)
    assert row.version == 1
    seqs = [row.server_seq]

    for amount in (5000, 5500, 6000):
        row.amount_minor = amount
        row.save()
        seqs.append(row.server_seq)

    assert row.version == 4
    assert seqs == sorted(set(seqs))
    stored = Expense.objects.get(pk=row.pk)
    assert (stored.version, stored.server_seq) == (4, seqs[-1])


def test_python_cannot_set_version_or_seq(user):
    row = make.expense(user)
    row.version = 99
    row.server_seq = 1

    row.save()

    assert row.version == 2
    assert row.server_seq > 1


def test_bulk_and_queryset_writes_are_stamped_too(user):
    """Any write path goes through the trigger, not just Model.save()."""
    Expense.objects.bulk_create(
        [Expense(owner=user, entity_id=f"bulk-{i}", amount_minor=100, currency="TND", category_id="food", date=make.DAY) for i in range(3)]
    )
    before = {e.entity_id: e.server_seq for e in Expense.objects.all()}
    assert all(before.values())

    Expense.objects.filter(entity_id="bulk-1").update(note="via queryset")

    after = Expense.objects.get(entity_id="bulk-1")
    assert after.version == 2
    assert after.server_seq > max(before.values())


def test_a_rolled_back_write_leaves_a_gap_not_a_reuse(user):
    first = make.expense(user)
    with pytest.raises(RuntimeError), transaction.atomic():
        make.expense(user)
        raise RuntimeError
    second = make.expense(user)

    assert second.server_seq > first.server_seq + 1


@pytest.mark.django_db(transaction=True)
def test_writes_commit_in_server_seq_order(user):
    """A takes a seq and holds its transaction open; B's write must wait for
    A to commit, then get a larger seq. So a pull that has seen B's seq can
    never later find A's smaller seq appearing (ADR 0005)."""
    a_wrote = threading.Event()
    a_may_commit = threading.Event()
    seen = {}
    commits = []
    errors = []

    def run(name, body):
        try:
            body()
        except Exception as e:  # noqa: BLE001 - surfaced by the assert below
            errors.append((name, e))
        finally:
            connection.close()

    def a():
        with transaction.atomic():
            seen["a"] = make.expense(user, "a").server_seq
            a_wrote.set()
            a_may_commit.wait(10)
        commits.append("a")

    def b():
        a_wrote.wait(10)
        with transaction.atomic():
            seen["b"] = make.expense(user, "b").server_seq
        commits.append("b")

    threads = [threading.Thread(target=run, args=(n, f)) for n, f in (("a", a), ("b", b))]
    for t in threads:
        t.start()
    assert a_wrote.wait(10)
    time.sleep(0.5)
    assert "b" not in seen, "B wrote while A's transaction was still open"

    a_may_commit.set()
    for t in threads:
        t.join(10)

    assert not errors
    assert seen["b"] > seen["a"]
    assert commits == ["a", "b"]
