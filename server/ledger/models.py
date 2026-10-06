"""Server copies of the synced entities (ARCHITECTURE.md §4).

Field names follow the app's drift tables (`app/lib/features/*/data/db/`).
Money is integer minor units plus an ISO currency code, never a float.

Personal rows (expenses, categories, income sources, budgets) are keyed by
(owner, entity_id): every user has a `food` category and a `budget-2026-10`
(ADRs 0001, 0002). Group rows are keyed by entity_id alone (client UUIDs).

These constraints are a backstop. The sync service (task 3.4) validates every
op first and returns a reason; the database only refuses what must never exist.
"""

from django.conf import settings
from django.db import models
from django.db.models import F, Q

from groups.models import Group, Member
from sync.base import SyncedModel, currency_check


class PersonalModel(SyncedModel):
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+")

    class Meta:
        abstract = True


def _personal_constraints(prefix):
    return [
        models.UniqueConstraint(fields=["owner", "entity_id"], name=f"{prefix}_owner_entity_id_unique"),
        currency_check(f"{prefix}_currency_code"),
    ]


def _personal_indexes(prefix):
    # Pull: "this owner's rows with server_seq > cursor".
    return [models.Index(fields=["owner", "server_seq"], name=f"{prefix}_owner_seq")]


class Expense(PersonalModel):
    class Source(models.TextChoices):
        MANUAL = "manual"
        VOICE = "voice"
        RECEIPT = "receipt"

    amount_minor = models.BigIntegerField()
    currency = models.CharField(max_length=3)
    # Not a foreign key: it may be a built-in category with no stored row (ADR 0001).
    category_id = models.CharField(max_length=64)
    date = models.DateField()
    note = models.CharField(max_length=200, null=True, blank=True)
    source = models.CharField(max_length=16, choices=Source.choices, default=Source.MANUAL)

    class Meta:
        constraints = [
            *_personal_constraints("expense"),
            models.CheckConstraint(condition=Q(amount_minor__gt=0), name="expense_amount_positive"),
            models.CheckConstraint(condition=Q(source__in=["manual", "voice", "receipt"]), name="expense_source_valid"),
        ]
        indexes = _personal_indexes("expense")


class Category(PersonalModel):
    name = models.CharField(max_length=40)
    icon = models.CharField(max_length=40)
    monthly_limit_minor = models.BigIntegerField(null=True, blank=True)
    currency = models.CharField(max_length=3)
    archived = models.BooleanField(default=False)

    class Meta:
        verbose_name_plural = "categories"
        constraints = [
            *_personal_constraints("category"),
            models.CheckConstraint(
                condition=Q(monthly_limit_minor__isnull=True) | Q(monthly_limit_minor__gt=0),
                name="category_limit_positive",
            ),
        ]
        indexes = _personal_indexes("category")


class IncomeSource(PersonalModel):
    class Schedule(models.TextChoices):
        MONTHLY = "monthly"
        ONE_OFF = "oneOff"
        IRREGULAR = "irregular"

    name = models.CharField(max_length=60)
    amount_minor = models.BigIntegerField()
    currency = models.CharField(max_length=3)
    schedule_type = models.CharField(max_length=16, choices=Schedule.choices)
    # Monthly: the day it arrives. One-off: the date. Irregular: neither.
    day_of_month = models.PositiveSmallIntegerField(null=True, blank=True)
    date = models.DateField(null=True, blank=True)

    class Meta:
        constraints = [
            *_personal_constraints("income"),
            models.CheckConstraint(condition=Q(amount_minor__gt=0), name="income_amount_positive"),
            models.CheckConstraint(
                condition=(
                    # day_of_month__isnull=False is needed: a CHECK passes when it
                    # evaluates to NULL, and `NULL >= 1` is NULL, not false.
                    Q(
                        schedule_type="monthly",
                        day_of_month__isnull=False,
                        day_of_month__gte=1,
                        day_of_month__lte=31,
                        date__isnull=True,
                    )
                    | Q(schedule_type="oneOff", day_of_month__isnull=True, date__isnull=False)
                    | Q(schedule_type="irregular", day_of_month__isnull=True, date__isnull=True)
                ),
                name="income_schedule_valid",
            ),
        ]
        indexes = _personal_indexes("income")


class Budget(PersonalModel):
    """A month's overall limit. Its id is `budget-YYYY-MM` (ADR 0002)."""

    month = models.CharField(max_length=7)
    total_limit_minor = models.BigIntegerField(null=True, blank=True)
    currency = models.CharField(max_length=3)

    class Meta:
        constraints = [
            *_personal_constraints("budget"),
            models.CheckConstraint(condition=Q(month__regex=r"^[0-9]{4}-(0[1-9]|1[0-2])$"), name="budget_month_format"),
            models.CheckConstraint(
                condition=Q(total_limit_minor__isnull=True) | Q(total_limit_minor__gt=0),
                name="budget_limit_positive",
            ),
        ]
        indexes = _personal_indexes("budget")


class SharedExpense(SyncedModel):
    """An expense paid by one member for some of the group.

    `split` is the rule as entered ({"type": ..., ...}); `shares` is what the
    app's computeShares produced ({memberId: minor units}). Shares are stored,
    not recomputed, so rounding changes can't move old balances. The service
    checks they sum to the amount and name members of the group (task 4.2).
    """

    group = models.ForeignKey(Group, on_delete=models.CASCADE, related_name="expenses")
    # Members are never hard-deleted (removal is a tombstone), so PROTECT.
    payer = models.ForeignKey(Member, on_delete=models.PROTECT, related_name="+")
    amount_minor = models.BigIntegerField()
    currency = models.CharField(max_length=3)
    date = models.DateField()
    split = models.JSONField()
    shares = models.JSONField()
    category_id = models.CharField(max_length=64, null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["entity_id"], name="shared_expense_entity_id_unique"),
            models.CheckConstraint(condition=Q(amount_minor__gt=0), name="shared_expense_amount_positive"),
            currency_check("shared_expense_currency_code"),
        ]
        indexes = [models.Index(fields=["group", "server_seq"], name="shared_expense_group_seq")]


class Settlement(SyncedModel):
    """A payment between members. Insert-only: never updated (a database
    trigger refuses) and never deleted by the app. A mistake is undone with
    a reversing settlement, which points at the original via `reverses`."""

    group = models.ForeignKey(Group, on_delete=models.CASCADE, related_name="settlements")
    from_member = models.ForeignKey(Member, on_delete=models.PROTECT, related_name="+")
    to_member = models.ForeignKey(Member, on_delete=models.PROTECT, related_name="+")
    amount_minor = models.BigIntegerField()
    currency = models.CharField(max_length=3)
    date = models.DateField()
    reverses = models.OneToOneField(
        "self", null=True, blank=True, on_delete=models.PROTECT, related_name="reversed_by"
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["entity_id"], name="settlement_entity_id_unique"),
            models.CheckConstraint(condition=Q(amount_minor__gt=0), name="settlement_amount_positive"),
            models.CheckConstraint(condition=~Q(from_member=F("to_member")), name="settlement_not_to_self"),
            models.CheckConstraint(condition=Q(deleted=False), name="settlement_never_deleted"),
            currency_check("settlement_currency_code"),
        ]
        indexes = [models.Index(fields=["group", "server_seq"], name="settlement_group_seq")]
