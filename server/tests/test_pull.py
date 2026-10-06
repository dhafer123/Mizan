"""`/sync/pull`: scope (nothing leaks), tombstones, and page boundaries."""

import threading

import pytest
from django.db import connection, transaction

from accounts.models import User
from accounts.services import issue_tokens
from groups.models import Member
from sync import pull as pull_module

from . import ledger_factories as make
from .conftest import auth_client
from .sync_helpers import Device, create_expense, op

pytestmark = pytest.mark.django_db


def pull(user, since=0, limit=None, expect=200):
    query = {"since": since} | ({"limit": limit} if limit else {})
    response = auth_client(issue_tokens(user)["access"]).get("/sync/pull", query)
    assert response.status_code == expect, response.json()
    return response.json()


def everything(user, limit=500):
    """All pages, following the cursor."""
    changes, since = [], 0
    while True:
        page = pull(user, since, limit)
        changes += page["changes"]
        since = page["cursor"]
        if not page["hasMore"]:
            return changes


def keys(changes):
    return {(c["entity"], c["state"]["id"]) for c in changes}


@pytest.fixture
def ali(db):
    return User.objects.create_user(email="ali@example.com", password="x-long-password")


@pytest.fixture
def nour(db):
    return User.objects.create_user(email="nour@example.com", password="x-long-password")


# --- Scope ---


def test_own_personal_rows_including_tombstones(user):
    phone = Device(user)
    kept = create_expense(phone)["entityId"]
    gone = create_expense(phone)["entityId"]
    phone.one(op("expenses", gone, "delete", 1))
    phone.one(op("categories", "food", base=0, name="Groceries"))
    make.income(user, "i-1")
    make.budget(user, "2026-10")

    changes = everything(user)

    rows = {c["state"]["id"]: c["state"] for c in changes if c["entity"] != "entity_history"}
    assert set(rows) == {kept, gone, "food", "i-1", "budget-2026-10"}
    assert rows[gone]["deleted"] is True
    assert rows["food"]["name"] == "Groceries"


def test_nothing_from_other_users(user, ali):
    create_expense(Device(user), "mine")
    Device(ali).one(op("categories", "food", base=0, name="Ali's food"))
    create_expense(Device(ali), "theirs")
    make.budget(ali, "2026-10")

    changes = everything(user)

    assert keys(changes) >= {("expenses", "mine")}
    assert not any(c["state"].get("id") in {"theirs", "food", "budget-2026-10"} for c in changes)
    history = [c for c in changes if c["entity"] == "entity_history"]
    assert {h["state"]["entityId"] for h in history} == {"mine"}


@pytest.fixture
def groups(user, ali, nour):
    """Sami and Ali share a flat; Ali and Nour have a group Sami isn't in."""
    flat, trip = make.group(user, name="Flat"), make.group(ali, name="Trip")
    sami_m, ali_m = make.member(flat, user, "Sami"), make.member(flat, ali, "Ali")
    placeholder = make.member(flat, name="Old roommate")
    trip_ali, trip_nour = make.member(trip, ali, "Ali"), make.member(trip, nour, "Nour")
    flat_expense = make.shared_expense(flat, ali_m, {sami_m.entity_id: 3000, ali_m.entity_id: 3000})
    trip_expense = make.shared_expense(trip, trip_nour, {trip_ali.entity_id: 5000, trip_nour.entity_id: 5000})
    flat_settlement = make.settlement(flat, sami_m, ali_m)
    make.history(group=flat, entity="shared_expenses", entity_id=flat_expense.entity_id)
    make.history(group=trip, entity="shared_expenses", entity_id=trip_expense.entity_id)
    return {
        "flat": flat, "trip": trip, "sami": sami_m, "ali": ali_m, "placeholder": placeholder,
        "flat_expense": flat_expense, "trip_expense": trip_expense, "flat_settlement": flat_settlement,
        "trip_members": {trip_ali.entity_id, trip_nour.entity_id},
    }


def test_group_data_only_for_groups_youre_in(user, groups):
    changes = everything(user)

    got = keys(changes)
    assert ("groups", groups["flat"].entity_id) in got
    assert {("members", groups[m].entity_id) for m in ("sami", "ali", "placeholder")} <= got
    assert ("shared_expenses", groups["flat_expense"].entity_id) in got
    assert ("settlements", groups["flat_settlement"].entity_id) in got

    assert ("groups", groups["trip"].entity_id) not in got
    assert ("shared_expenses", groups["trip_expense"].entity_id) not in got
    assert not {("members", m) for m in groups["trip_members"]} & got
    history_ids = {c["state"]["entityId"] for c in changes if c["entity"] == "entity_history"}
    assert groups["trip_expense"].entity_id not in history_ids
    assert groups["flat_expense"].entity_id in history_ids


def test_member_rows_show_who_is_a_placeholder(user, groups):
    members = {c["state"]["id"]: c["state"] for c in everything(user) if c["entity"] == "members"}

    assert members[groups["sami"].entity_id]["userId"] == str(user.id)
    assert members[groups["placeholder"].entity_id]["userId"] is None
    assert members[groups["sami"].entity_id]["groupId"] == groups["flat"].entity_id


def test_a_removed_member_learns_it_and_then_gets_nothing_more(user, ali, groups):
    cursor = pull(user, 0, 500)["cursor"]
    removal = Member.objects.get(pk=groups["sami"].pk)
    removal.deleted = True
    removal.save()
    later = make.shared_expense(groups["flat"], groups["ali"], {groups["ali"].entity_id: 1000})

    page = pull(user, cursor)

    assert keys(page["changes"]) == {("members", groups["sami"].entity_id)}
    assert page["changes"][0]["state"]["deleted"] is True
    assert ("shared_expenses", later.entity_id) not in keys(everything(user))


def test_a_deleted_group_stops_syncing(user, groups):
    flat = groups["flat"]
    flat.deleted = True
    flat.save()

    assert ("groups", flat.entity_id) not in keys(everything(user))


# --- Changes and cursors ---


def test_only_changes_after_the_cursor(user):
    phone = Device(user)
    first = create_expense(phone)["entityId"]
    cursor = pull(user)["cursor"]

    second = create_expense(phone)["entityId"]
    phone.one(op("expenses", first, base=1, note="edited"))
    page = pull(user, cursor)

    expenses = [c for c in page["changes"] if c["entity"] == "expenses"]
    assert [c["state"]["id"] for c in expenses] == [second, first]
    assert expenses[1]["state"]["note"] == "edited"


def test_an_edited_row_appears_once_at_its_latest_seq(user):
    phone = Device(user)
    expense_id = create_expense(phone)["entityId"]
    for note in ("a", "b", "c"):
        phone.one(op("expenses", expense_id, base=1, note=note))

    expenses = [c for c in everything(user) if c["entity"] == "expenses"]

    assert len(expenses) == 1
    assert expenses[0]["state"]["note"] == "c"
    assert expenses[0]["serverSeq"] == expenses[0]["state"]["serverSeq"]


def test_changes_are_in_seq_order_and_history_has_its_shape(user):
    phone = Device(user)
    expense_id = create_expense(phone, amountMinor=120_000)["entityId"]
    phone.one(op("expenses", expense_id, base=1, amountMinor=150_000))

    changes = everything(user)

    seqs = [c["serverSeq"] for c in changes]
    assert seqs == sorted(seqs) and len(set(seqs)) == len(seqs)
    changed = next(c["state"] for c in changes if c["entity"] == "entity_history" and c["state"]["kind"] == "changed")
    assert set(changed) == {
        "id", "entity", "entityId", "kind", "field", "oldValue", "newValue", "changedBy", "serverSeq", "changedAt",
    }
    assert (changed["field"], changed["oldValue"], changed["newValue"]) == ("amountMinor", 120_000, 150_000)
    assert changed["changedAt"].endswith("Z")


def test_nothing_new(user):
    create_expense(Device(user))
    cursor = pull(user)["cursor"]

    assert pull(user, cursor) == {"changes": [], "cursor": cursor, "hasMore": False}
    assert pull(user, cursor + 1000) == {"changes": [], "cursor": cursor + 1000, "hasMore": False}


def test_a_new_account_starts_empty(user):
    assert pull(user) == {"changes": [], "cursor": 0, "hasMore": False}


# --- Pages ---


@pytest.fixture
def ten_rows(user, groups):
    """Rows spread over several tables, so pages cut across them."""
    for i in range(3):
        make.expense(user, f"e-{i}")
    make.category(user, "food")
    make.budget(user, "2026-10")
    return everything(user)


def test_pages_cover_everything_once_in_order(user, ten_rows):
    for limit in (1, 2, 3, 7):
        walked = everything(user, limit)
        assert [c["serverSeq"] for c in walked] == [c["serverSeq"] for c in ten_rows], limit


def test_page_boundaries(user, ten_rows):
    total = len(ten_rows)

    exact = pull(user, 0, total)
    one_short = pull(user, 0, total - 1)
    last = pull(user, one_short["cursor"], total)

    assert (len(exact["changes"]), exact["hasMore"]) == (total, False)
    assert exact["cursor"] == ten_rows[-1]["serverSeq"]
    assert (len(one_short["changes"]), one_short["hasMore"]) == (total - 1, True)
    assert one_short["cursor"] == ten_rows[-2]["serverSeq"]
    assert (last["changes"], last["hasMore"]) == ([ten_rows[-1]], False)


def test_the_default_page_size_is_200(user):
    for i in range(201):
        make.expense(user, f"e-{i}")

    page = pull(user)

    assert (len(page["changes"]), page["hasMore"]) == (200, True)


@pytest.mark.parametrize("query", [{"since": -1}, {"since": "x"}, {"limit": 0}, {"limit": 501}])
def test_bad_queries(user, query):
    response = auth_client(issue_tokens(user)["access"]).get("/sync/pull", query)

    assert response.status_code == 400


def test_pull_needs_a_signed_in_user(client):
    assert client.get("/sync/pull").status_code == 401


# --- No gaps under concurrent writes ---


@pytest.mark.django_db(transaction=True)
def test_a_page_never_skips_a_row_committed_while_it_was_read(user, monkeypatch):
    """Between the page's expenses query and its categories query, another
    request commits an expense (seq N) and then a category (seq N+1). If the
    queries saw different snapshots, the page would hold N+1 but not N, and
    the cursor would jump past N for good."""
    real_fetch = pull_module._fetch

    def write_concurrently():
        try:
            with transaction.atomic():
                make.expense(user, "late-expense")
            with transaction.atomic():
                make.category(user, "late-category")
        finally:
            connection.close()

    def fetch(source, *args):
        rows = real_fetch(source, *args)
        if source.entity == "expenses":
            writer = threading.Thread(target=write_concurrently)
            writer.start()
            writer.join(10)
        return rows

    monkeypatch.setattr(pull_module, "_fetch", fetch)
    first = pull(user)
    monkeypatch.setattr(pull_module, "_fetch", real_fetch)
    second = pull(user, first["cursor"])

    assert keys(first["changes"]) == set(), "rows committed mid-page must wait for the next page"
    assert keys(second["changes"]) == {("expenses", "late-expense"), ("categories", "late-category")}
