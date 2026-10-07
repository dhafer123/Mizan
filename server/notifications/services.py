"""Who hears about what (task 4.6, ARCHITECTURE.md §9).

Every push carries a "data changed" signal: the app syncs when it gets one,
so a change on one phone shows on the others within seconds. Some also show
a notification:

| Event                              | Data push to                   | Notification to             |
|------------------------------------|--------------------------------|-----------------------------|
| personal rows pushed               | the account's other phones     | -                           |
| group rows pushed                  | every member's phones, except  | -                           |
|                                    | the one that pushed            |                             |
| a new shared expense               | (as above)                     | the other members           |
| someone joins a group (invite)     | every member's phones          | the other members           |
| weekly reminder (management cmd)   | -                              | each member who owes money  |
"""

from groups.balances import balances
from groups.models import Group, Member
from sync.entities import ENTITIES, GROUP

from .delivery import Push, send

# Digits after the decimal point, as in the app's Currency enum.
DECIMALS = {"TND": 3, "EUR": 2, "USD": 2}


def format_money(minor, currency):
    digits = DECIMALS.get(currency, 2)
    sign = "-" if minor < 0 else ""
    major, rest = divmod(abs(minor), 10**digits)
    return f"{sign}{major}.{rest:0{digits}d} {currency}" if digits else f"{sign}{major} {currency}"


def after_push(user, device_id, applied):
    """`applied`: (op type, result) for each op this push just applied or
    merged (not replays of earlier ones, not rejections)."""
    group_ids, personal, new_expenses = set(), False, {}
    for op_type, result in applied:
        entity, state = result["entity"], result["state"] or {}
        if ENTITIES[entity].scope != GROUP:
            personal = True
            continue
        group_id = result["entityId"] if entity == "groups" else state.get("groupId")
        group_ids.add(group_id)
        if entity == "shared_expenses" and op_type == "create":
            new_expenses.setdefault(group_id, []).append(state)

    pushes = {}
    if personal:
        pushes[user.pk] = Push(user.pk)
    groups = Group.objects.filter(entity_id__in=group_ids, deleted=False)
    members = Member.objects.filter(group__in=groups, deleted=False)
    names = {m.entity_id: m.display_name for m in members}
    for group in groups:
        expenses = new_expenses.get(group.entity_id, [])
        for member in members:
            if member.group_id != group.pk or member.user_id is None:
                continue
            if expenses and member.user_id != user.pk:
                pushes[member.user_id] = Push(
                    member.user_id, group.name, _expenses_text(expenses, names), group.entity_id
                )
            else:
                pushes.setdefault(member.user_id, Push(member.user_id, group_id=group.entity_id))
    send(pushes.values(), except_device=device_id)


def _expenses_text(expenses, names):
    if len(expenses) > 1:
        return f"{len(expenses)} new expenses"
    (e,) = expenses
    payer = names.get(e["payerId"], "Someone")
    return f"{payer} paid {format_money(e['amountMinor'], e['currency'])}"


def joined(user, group, member):
    """`user` joined `group` as `member` through an invite."""
    others = Member.objects.filter(group=group, deleted=False, user__isnull=False).exclude(user=user)
    send(
        [
            Push(user.pk, group_id=group.entity_id),
            *(
                Push(m.user_id, group.name, f"{member.display_name} joined the group", group.entity_id)
                for m in others
            ),
        ]
    )


def settle_up_reminders():
    """Reminds every member who owes money in a group. Run weekly. Returns
    how many reminders went out."""
    pushes = []
    for group in Group.objects.filter(deleted=False):
        owed = {member: minor for member, minor in balances(group).items() if minor < 0}
        if not owed:
            continue
        for member in Member.objects.filter(group=group, entity_id__in=owed, deleted=False, user__isnull=False):
            amount = format_money(-owed[member.entity_id], group.currency)
            pushes.append(Push(member.user_id, group.name, f"You owe {amount}. Settle up when you can.", group.entity_id))
    send(pushes)
    return len(pushes)
