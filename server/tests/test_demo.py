"""The demo seed (task 6.7): believable, valid, and repeatable."""

from datetime import date, timedelta

import pytest

from accounts.models import User
from demo import services
from groups.balances import balances
from groups.models import Member
from ledger.models import Budget, Expense, IncomeSource

TODAY = date(2026, 10, 18)


@pytest.fixture
def seeded(db):
    return services.seed(TODAY)


def test_two_accounts_share_the_flat(seeded):
    dhafer, sami, group = seeded
    members = Member.objects.filter(group=group)
    assert {m.user for m in members} == {dhafer, sami}
    assert group.name == "Flat 4B"


def test_the_flat_balances_sum_to_zero_and_dhafer_owes_sami(seeded):
    dhafer, sami, group = seeded
    owed = balances(group)
    assert sum(owed.values()) == 0
    # Sami paid 45 for internet, Dhafer 18 for cleaning: Dhafer owes 13.5.
    dhafer_member = Member.objects.get(group=group, user=dhafer).entity_id
    assert owed[dhafer_member] == -13_500


def test_four_weeks_of_spending_up_to_yesterday(seeded):
    dhafer, _, _ = seeded
    days = set(Expense.objects.filter(owner=dhafer).values_list("date", flat=True))
    assert min(days) == TODAY - timedelta(days=28)
    assert max(days) == TODAY - timedelta(days=1)
    assert len(days) == 28, "something every day, so the forecast learns a rate"


def test_the_money_runs_out_before_the_next_payday(seeded):
    dhafer, _, _ = seeded
    expenses = Expense.objects.filter(owner=dhafer)
    this_month = sum(e.amount_minor for e in expenses if e.date.month == TODAY.month)
    money_left = services.INCOME - this_month
    daily = sum(e.amount_minor for e in expenses) / 28
    days_until_payday = (date(2026, 11, 1) - TODAY).days

    assert money_left > 0, "not broke yet"
    assert 3 <= money_left / daily < days_until_payday - 3, "runs out about a week early"


def test_seeding_twice_needs_a_reset(seeded):
    with pytest.raises(services.DemoError):
        services.seed(TODAY)

    services.reset()
    assert not User.objects.filter(email__in=[services.DHAFER[0], services.SAMI[0]]).exists()
    services.seed(TODAY)


def test_sami_pays_what_he_owes(seeded):
    dhafer, sami, group = seeded
    # Dhafer pays the rent, as in the video: now Sami owes him.
    me = Member.objects.get(group=group, user=dhafer).entity_id
    roommate = Member.objects.get(group=group, user=sami).entity_id
    services._push(dhafer, services._op(
        "shared_expenses", "rent-1", id="rent-1", groupId=group.entity_id, payerId=me, amountMinor=600_000,
        currency="TND", date=services._day(TODAY), split={"type": "equal", "memberIds": [me, roommate]},
        shares=services.equal_shares(600_000, [me, roommate]), categoryId="rent"))

    assert services.roommate_pays(TODAY) == 286_500
    assert balances(group)[roommate] == 0
    assert services.roommate_pays(TODAY) == 0, "nothing left to pay"


def test_for_onboarding_the_income_and_budget_are_left_to_the_app(db):
    dhafer, _, _ = services.seed(TODAY, onboarding=True)

    assert not IncomeSource.objects.filter(owner=dhafer).exists()
    assert not Budget.objects.filter(owner=dhafer).exists()
    assert Expense.objects.filter(owner=dhafer).exists(), "the history is still there"


def test_equal_shares_add_up_with_extra_millimes_to_the_lowest_ids():
    assert services.equal_shares(10, ["c", "a", "b"]) == {"a": 4, "b": 3, "c": 3}
