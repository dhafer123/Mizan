"""A group's balances, computed from its rows (never stored), the same way
the app's GroupBalances does: what a member paid minus their shares, plus
payments they made, minus payments they received. They sum to 0."""

from collections import defaultdict

from ledger.models import SharedExpense, Settlement


def balances(group):
    """{member entity id: minor units}; positive means the group owes them."""
    totals = defaultdict(int)
    for payer, amount, shares in SharedExpense.objects.filter(group=group, deleted=False).values_list(
        "payer__entity_id", "amount_minor", "shares"
    ):
        totals[payer] += amount
        for member, share in shares.items():
            totals[member] -= share
    for payer, payee, amount in Settlement.objects.filter(group=group).values_list(
        "from_member__entity_id", "to_member__entity_id", "amount_minor"
    ):
        totals[payer] += amount
        totals[payee] -= amount
    return dict(totals)
