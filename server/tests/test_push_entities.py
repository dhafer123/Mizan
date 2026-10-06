"""Per-entity rules: the server re-validates every op (CLAUDE.md rule 8)."""

import re
import uuid
from pathlib import Path

import pytest

from ledger.models import Budget, Category, IncomeSource
from sync.entities import BUILT_IN_CATEGORIES
from sync.models import EntityHistory

from . import ledger_factories as make
from .sync_helpers import DAY, Device, create_expense, expense_fields, op

pytestmark = pytest.mark.django_db


@pytest.fixture
def phone(user):
    return Device(user)


# --- The envelope and op shape ---


def test_the_result_state_is_shaped_like_the_apps_row(phone, user):
    """Keys and formats of ExpenseRow.toJson, so the app can store it as is."""
    result = create_expense(phone, "e-1", note="lunch")

    state = result["state"]
    assert set(state) == {
        "id", "amountMinor", "currency", "categoryId", "date", "note", "source",
        "version", "deleted", "updatedBy", "serverSeq",
    }
    assert state["date"] == DAY
    assert state["updatedBy"] == str(user.id)
    assert (result["opId"], result["entity"], result["entityId"], result["status"]) == (
        result["opId"], "expenses", "e-1", "applied",
    )


@pytest.mark.parametrize(
    ("body", "field"),
    [
        ({"ops": []}, "deviceId"),
        ({"deviceId": "not-a-uuid", "ops": []}, "deviceId"),
        ({"deviceId": str(uuid.uuid4())}, "ops"),
        ({"deviceId": str(uuid.uuid4()), "ops": [{}] * 201}, "ops"),
    ],
)
def test_a_bad_envelope_is_a_400(phone, body, field):
    response = phone.client.post("/sync/push", body, format="json")

    assert response.status_code == 400
    assert field in response.json()["fields"]


def test_a_malformed_op_is_rejected_alone(phone):
    good = op("expenses", "e-1", "create", 0, **expense_fields("e-1"))

    results = phone.push(
        "not an op",
        {**good, "opId": "nope"},
        {**good, "opType": "upsert"},
        {**good, "baseVersion": -1},
        {**good, "entityId": "has spaces"},
        good,
    )

    assert [r.get("field") for r in results[1:5]] == ["opId", "opType", "baseVersion", "entityId"]
    assert all(r["reason"] == "invalid_op" for r in results[:5])
    assert results[5]["status"] == "applied"


@pytest.mark.parametrize(
    ("fields", "reason", "field"),
    [
        ({"amountMinor": 0}, "invalid_field", "amountMinor"),
        ({"amountMinor": 4.5}, "invalid_field", "amountMinor"),
        ({"amountMinor": True}, "invalid_field", "amountMinor"),
        ({"amountMinor": "4500"}, "invalid_field", "amountMinor"),
        ({"currency": "tnd"}, "invalid_field", "currency"),
        ({"currency": "GBP"}, "invalid_field", "currency"),
        ({"date": "2026-10-06T13:00:00.000Z"}, "invalid_field", "date"),
        ({"date": "2026-10-06T00:00:00.000+01:00"}, "invalid_field", "date"),
        ({"date": "yesterday"}, "invalid_field", "date"),
        ({"note": "x" * 201}, "invalid_field", "note"),
        ({"source": "fax"}, "invalid_field", "source"),
        ({"categoryId": ""}, "invalid_field", "categoryId"),
        ({"id": "another-id"}, "invalid_field", "id"),
        ({"colour": "red"}, "unknown_field", "colour"),
        ({"version": 5}, "unknown_field", "version"),
        ({"serverSeq": 1}, "unknown_field", "serverSeq"),
    ],
)
def test_invalid_expense_fields(phone, fields, reason, field):
    result = phone.one(op("expenses", "e-1", "create", 0, **expense_fields("e-1", **fields)))

    assert (result["status"], result["reason"], result["field"]) == ("rejected", reason, field)


def test_a_create_needs_every_required_field(phone):
    fields = expense_fields("e-1")
    del fields["categoryId"]

    result = phone.one(op("expenses", "e-1", "create", 0, **fields))

    assert (result["reason"], result["field"]) == ("missing_field", "categoryId")


def test_optional_fields_may_be_left_out_of_a_create(phone):
    fields = expense_fields("e-1")
    del fields["note"]

    assert phone.one(op("expenses", "e-1", "create", 0, **fields))["state"]["note"] is None


def test_unknown_entities_and_missing_rows(phone):
    assert phone.one(op("receipts", "r-1", "create", 0))["reason"] == "unknown_entity"
    assert phone.one(op("expenses", "missing", base=1, note="x"))["reason"] == "not_found"
    assert phone.one(op("expenses", "missing", "delete", 1))["reason"] == "not_found"


def test_a_base_version_from_the_future_is_rejected(phone):
    expense_id = create_expense(phone)["entityId"]

    result = phone.one(op("expenses", expense_id, base=7, note="x"))

    assert result["reason"] == "bad_base_version"
    assert result["state"]["version"] == 1


def test_an_update_that_changes_nothing_writes_nothing(phone):
    expense_id = create_expense(phone, amountMinor=4500)["entityId"]

    result = phone.one(op("expenses", expense_id, base=1, amountMinor=4500))

    assert result["status"] == "applied"
    assert result["state"]["version"] == 1


def test_every_change_is_in_history_with_old_and_new_values(phone):
    expense_id = create_expense(phone, amountMinor=120_000)["entityId"]
    phone.one(op("expenses", expense_id, base=1, amountMinor=150_000, date="2026-10-07T00:00:00.000Z"))

    rows = {h.field: h for h in EntityHistory.objects.filter(entity_id=expense_id, kind="changed")}
    assert (rows["amountMinor"].old_value, rows["amountMinor"].new_value) == (120_000, 150_000)
    assert (rows["date"].old_value, rows["date"].new_value) == (DAY, "2026-10-07T00:00:00.000Z")
    assert {h.version for h in rows.values()} == {2}
    assert EntityHistory.objects.filter(entity_id=expense_id, kind="created").count() == 1


# --- Categories: built-ins exist implicitly at version 0 (ADR 0001) ---


def test_first_edit_of_a_built_in_category_stores_it(phone, user):
    result = phone.one(op("categories", "food", base=0, name="Groceries"))

    assert result["status"] == "applied"
    assert result["state"] | {"serverSeq": None, "updatedBy": None} == {
        "id": "food", "name": "Groceries", "icon": "food", "monthlyLimitMinor": None,
        "currency": "TND", "archived": False, "version": 1, "deleted": False,
        "updatedBy": None, "serverSeq": None,
    }
    assert Category.objects.get(owner=user, entity_id="food").name == "Groceries"


def test_two_devices_editing_the_same_built_in_merge(user):
    phone, laptop = Device(user), Device(user)

    phone.one(op("categories", "rent", base=0, name="Housing"))
    second = laptop.one(op("categories", "rent", base=0, name="Flat", archived=False, monthlyLimitMinor=900_000))

    assert second["status"] == "merged"
    row = Category.objects.get(owner=user, entity_id="rent")
    assert (row.name, row.monthly_limit_minor) == ("Flat", 900_000)
    assert EntityHistory.objects.get(entity_id="rent", kind="overwritten").old_value == "Housing"


def test_categories_are_archived_not_deleted(phone):
    phone.one(op("categories", "food", base=0, archived=True))

    result = phone.one(op("categories", "food", "delete", 1))

    assert result["reason"] == "not_deletable"


def test_an_unknown_category_id_needs_a_create(phone):
    assert phone.one(op("categories", "snacks", base=0, name="Snacks"))["reason"] == "not_found"


def test_built_in_categories_match_the_app():
    source = Path(__file__).resolve().parents[2] / "app/lib/features/expenses/domain/entities/default_categories.dart"
    pairs = re.findall(r"Category\(\s*id: '(\w+)',\s*name: '([^']+)',\s*icon: '(\w+)'", source.read_text())

    assert {i: (n, ic) for i, n, ic in pairs} == {
        i: (v["name"], v["icon"]) for i, v in BUILT_IN_CATEGORIES.items()
    }


# --- Budgets: id derived from the month (ADR 0002) ---


def budget_op(month="2026-10", limit=600_000, op_type="create", **extra):
    entity_id = f"budget-{month}"
    return op("budgets", entity_id, op_type, 0, id=entity_id, month=month, totalLimitMinor=limit, currency="TND", **extra)


def test_two_devices_creating_the_same_month_merge(user):
    phone, laptop = Device(user), Device(user)

    first = phone.one(budget_op(limit=600_000))
    second = laptop.one(budget_op(limit=550_000))

    assert (first["status"], second["status"]) == ("applied", "merged")
    assert Budget.objects.get(owner=user).total_limit_minor == 550_000
    assert EntityHistory.objects.get(entity_id="budget-2026-10", kind="overwritten").old_value == 600_000


def test_a_budget_month_must_match_its_id(phone):
    result = phone.one(op("budgets", "budget-2026-10", "create", 0, month="2026-11", totalLimitMinor=1, currency="TND"))

    assert (result["reason"], result["field"]) == ("month_mismatch", "month")


# --- Income sources: the schedule must make sense after a merge ---


def test_a_schedule_that_no_longer_makes_sense_is_rejected(phone, user):
    phone.one(op("income_sources", "i-1", "create", 0, id="i-1", name="Scholarship", amountMinor=250_000,
                 currency="TND", scheduleType="monthly", dayOfMonth=5, date=None))

    bad = phone.one(op("income_sources", "i-1", base=1, scheduleType="oneOff"))
    good = phone.one(op("income_sources", "i-1", base=1, scheduleType="oneOff", dayOfMonth=None,
                        date="2026-11-01T00:00:00.000Z"))

    assert (bad["reason"], bad["field"]) == ("invalid_schedule", "scheduleType")
    assert good["status"] == "applied"
    assert IncomeSource.objects.get(owner=user).date.isoformat() == "2026-11-01"


# --- Shared expenses: shares must add up, in the group's currency ---


@pytest.fixture
def flat(user):
    g = make.group(user)
    return g, make.member(g, user, "Sami"), make.member(g, name="Ali (placeholder)")


def shared(g, payer, shares, entity_id="s-1", **overrides):
    fields = {
        "id": entity_id, "groupId": g.entity_id, "payerId": payer.entity_id, "amountMinor": 6000,
        "currency": "TND", "date": DAY, "split": {"type": "equal"}, "shares": shares, "categoryId": None,
        **overrides,
    }
    return op("shared_expenses", entity_id, "create", 0, **fields)


def test_shares_must_add_up_to_the_amount(phone, flat):
    g, sami, ali = flat

    bad = phone.one(shared(g, sami, {sami.entity_id: 3000, ali.entity_id: 2999}))
    good = phone.one(shared(g, sami, {sami.entity_id: 3001, ali.entity_id: 2999}))

    assert (bad["reason"], bad["field"]) == ("shares_mismatch", "shares")
    assert good["status"] == "applied"
    assert good["state"]["shares"] == {sami.entity_id: 3001, ali.entity_id: 2999}


def test_changing_the_amount_alone_breaks_the_shares(phone, flat):
    g, sami, ali = flat
    phone.one(shared(g, sami, {sami.entity_id: 3000, ali.entity_id: 3000}))

    result = phone.one(op("shared_expenses", "s-1", base=1, amountMinor=9000))

    assert result["reason"] == "shares_mismatch"


@pytest.mark.parametrize(
    ("overrides", "reason", "field"),
    [
        ({"currency": "EUR"}, "currency_mismatch", "currency"),
        ({"split": {"type": "magic"}}, "invalid_split", "split"),
    ],
)
def test_other_shared_expense_rules(phone, flat, overrides, reason, field):
    g, sami, ali = flat

    result = phone.one(shared(g, sami, {sami.entity_id: 6000}, **overrides))

    assert (result["reason"], result["field"]) == (reason, field)


def test_no_sharers_is_invalid(phone, flat):
    g, sami, ali = flat

    result = phone.one(shared(g, sami, {}))

    assert (result["reason"], result["field"]) == ("invalid_field", "shares")


def test_a_negative_share_is_invalid(phone, flat):
    g, sami, ali = flat

    result = phone.one(shared(g, sami, {sami.entity_id: 7000, ali.entity_id: -1000}))

    assert (result["reason"], result["field"]) == ("invalid_field", "shares")


def test_settlement_needs_two_different_members(phone, flat):
    g, sami, ali = flat
    fields = {"id": "t-1", "groupId": g.entity_id, "fromMemberId": sami.entity_id, "toMemberId": sami.entity_id,
              "amountMinor": 100, "currency": "TND", "date": DAY, "reversesId": None}

    result = phone.one(op("settlements", "t-1", "create", 0, **fields))

    assert (result["reason"], result["field"]) == ("same_member", "toMemberId")
