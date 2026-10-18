"""Demo data for the video (task 6.7): two accounts, Dhafer and his roommate
Sami, with a month of Dhafer's spending and a shared flat.

Everything goes through `sync.push.push`, the same service that checks every
phone's changes, so seeded rows pass the same rules (share sums, membership,
permissions). Dates are relative to `today`, so the data always looks fresh:
four weeks of spending up to yesterday, paced so the money runs out about a
week before the next payday on the 1st.
"""

import random
import uuid
from datetime import date, timedelta

from django.db import transaction

from accounts.models import User
from accounts.services import sign_up
from groups.balances import balances
from groups.models import Group, Member
from groups.services import create_invite, join
from ledger.models import Settlement, SharedExpense
from sync.push import push

PASSWORD = "mizan-demo-2026"
DHAFER = ("dhafer@example.com", "Dhafer")
SAMI = ("sami@example.com", "Sami")
GROUP_NAME = "Flat 4B"
CURRENCY = "TND"

INCOME = 450_000  # millimes: a 450 DT scholarship, paid on the 1st
BUDGET = 450_000
FOOD_LIMIT = 260_000


class DemoError(Exception):
    """A seeded change the server refused, with its reason."""


def _day(d):
    return f"{d.isoformat()}T00:00:00.000Z"


def _op(entity, entity_id, op_type="create", base=0, **fields):
    return {
        "opId": str(uuid.uuid4()),
        "entity": entity,
        "entityId": entity_id,
        "opType": op_type,
        "baseVersion": base,
        "changedFields": fields,
    }


def _push(user, *ops):
    """Pushes as the user's demo device; every op must be applied."""
    results = push(user, _device_id(user), list(ops))
    refused = [r for r in results if r["status"] not in ("applied", "merged")]
    if refused:
        raise DemoError(", ".join(f"{r['entity']} {r.get('reason')} {r.get('field') or ''}".strip() for r in refused))
    return results


def _device_id(user):
    # One stable "seed phone" per account, so history reads the same.
    return uuid.uuid5(uuid.NAMESPACE_URL, f"mizan-demo-device:{user.email}")


def equal_shares(amount, member_ids):
    """The app's equal split: largest remainder, ties to the lowest id."""
    ordered = sorted(member_ids)
    base, extra = divmod(amount, len(ordered))
    return {m: base + (1 if i < extra else 0) for i, m in enumerate(ordered)}


def daily_spending(day, rng):
    """(note, category, millimes) a student spends on `day`: coffee most
    days, lunch and taxis on weekdays, printing for class, the weekly shop
    and a film on Saturday, brunch on Sunday. About 19 DT a day."""
    items = []
    weekday = day.weekday()  # Monday is 0
    if rng.random() < 0.85:
        items.append(("Coffee", "food", 2_000))
    if weekday < 5:
        items.append(("Lunch", "food", rng.choice([7_500, 8_000, 8_500, 9_000])))
        if rng.random() < 0.55:
            items.append(("Taxi", "transport", rng.choice([5_500, 6_000, 7_000])))
        if weekday in (0, 2):
            items.append(("Printing", "study", 3_000))
    elif weekday == 5:
        items.append(("Groceries", "food", rng.choice([26_000, 28_500, 31_000])))
        items.append(("Cinema", "leisure", 12_000))
    else:
        items.append(("Brunch", "food", 15_000))
    return items


@transaction.atomic
def reset():
    """Removes the demo accounts, their flat and everything in them."""
    users = User.objects.filter(email__in=[DHAFER[0], SAMI[0]])
    groups = Group.objects.filter(members__user__in=users).distinct()
    # Expenses and payments protect the members they name: they go first.
    SharedExpense.objects.filter(group__in=groups).delete()
    Settlement.objects.filter(group__in=groups).delete()
    Group.objects.filter(pk__in=list(groups.values_list("pk", flat=True))).delete()
    users.delete()


def seed(today=None):
    """Creates both accounts and their data. Returns (dhafer, sami, group)."""
    today = today or date.today()
    if User.objects.filter(email__in=[DHAFER[0], SAMI[0]]).exists():
        raise DemoError("Demo accounts exist already: reset first.")

    dhafer, _ = sign_up(email=DHAFER[0], password=PASSWORD, display_name=DHAFER[1])
    sami, _ = sign_up(email=SAMI[0], password=PASSWORD, display_name=SAMI[1])

    # --- Dhafer's month: income, budget, a food limit, four weeks of spending ---
    month = today.strftime("%Y-%m")
    income_id = str(uuid.uuid4())
    personal = [
        _op("income_sources", income_id, id=income_id, name="Scholarship", amountMinor=INCOME,
            currency=CURRENCY, scheduleType="monthly", dayOfMonth=1, date=None),
        _op("budgets", f"budget-{month}", id=f"budget-{month}", month=month,
            totalLimitMinor=BUDGET, currency=CURRENCY),
        _op("categories", "food", "update", 0, monthlyLimitMinor=FOOD_LIMIT),
    ]
    rng = random.Random(2026)  # the same month on every run
    for back in range(28, 0, -1):
        day = today - timedelta(days=back)
        for note, category, amount in daily_spending(day, rng):
            expense_id = str(uuid.uuid4())
            personal.append(_op("expenses", expense_id, id=expense_id, amountMinor=amount, currency=CURRENCY,
                                categoryId=category, date=_day(day), note=note, source="manual"))
    _push(dhafer, *personal)

    # --- The flat: Dhafer founds it, Sami joins through a real invite ---
    group_id, me, roommate = (str(uuid.uuid4()) for _ in range(3))
    _push(
        dhafer,
        _op("groups", group_id, id=group_id, name=GROUP_NAME, currency=CURRENCY),
        _op("members", me, id=me, groupId=group_id, userId=str(dhafer.pk), displayName=DHAFER[1]),
        _op("members", roommate, id=roommate, groupId=group_id, userId=None, displayName=SAMI[1]),
    )
    invite = create_invite(dhafer, group_id, roommate)
    join(sami, invite.token)

    # Bills from before the video: Sami paid the internet (45 DT), Dhafer
    # the cleaning things (18 DT), split equally. Rent is left for the video.
    members = [me, roommate]
    for user, payer, amount, back in [
        (sami, roommate, 45_000, 15),
        (dhafer, me, 18_000, 8),
    ]:
        expense_id = str(uuid.uuid4())
        _push(user, _op("shared_expenses", expense_id, id=expense_id, groupId=group_id, payerId=payer,
                        amountMinor=amount, currency=CURRENCY, date=_day(today - timedelta(days=back)),
                        split={"type": "equal", "memberIds": members}, shares=equal_shares(amount, members),
                        categoryId="other"))

    return dhafer, sami, Group.objects.get(entity_id=group_id)


def roommate_pays(today=None):
    """Sami pays Dhafer whatever he owes in the flat, from "his phone".
    Returns the amount in millimes (0 when he owes nothing)."""
    today = today or date.today()
    sami = User.objects.get(email=SAMI[0])
    group = Group.objects.get(members__user=sami, name=GROUP_NAME)
    sami_member = Member.objects.get(group=group, user=sami)
    dhafer_member = Member.objects.get(group=group, user__email=DHAFER[0])
    owes = -balances(group).get(sami_member.entity_id, 0)
    if owes <= 0:
        return 0
    settlement_id = str(uuid.uuid4())
    _push(sami, _op("settlements", settlement_id, id=settlement_id, groupId=group.entity_id,
                    fromMemberId=sami_member.entity_id, toMemberId=dhafer_member.entity_id,
                    amountMinor=owes, currency=CURRENCY, date=_day(today)))
    return owes
