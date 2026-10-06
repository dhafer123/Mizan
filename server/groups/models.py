from django.conf import settings
from django.db import models
from django.db.models import Q

from sync.base import SyncedModel, currency_check


class Group(SyncedModel):
    """A shared-expense group. One currency per group (ARCHITECTURE.md §1)."""

    name = models.CharField(max_length=60)
    currency = models.CharField(max_length=3)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="+"
    )

    class Meta:
        constraints = [
            # Group-side ids are client UUIDs, unique across the server.
            models.UniqueConstraint(fields=["entity_id"], name="group_entity_id_unique"),
            currency_check("group_currency_code"),
        ]

    def __str__(self):
        return self.name


class Member(SyncedModel):
    """Someone in a group. `user` is null for a placeholder until a real
    user claims it (task 4.1). Removing a member sets `deleted`: the row
    stays, so their expenses and settlements keep a payer."""

    group = models.ForeignKey(Group, on_delete=models.CASCADE, related_name="members")
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="memberships"
    )
    display_name = models.CharField(max_length=50)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["entity_id"], name="member_entity_id_unique"),
            # A user is in a group at most once (removed members don't count).
            models.UniqueConstraint(
                fields=["group", "user"],
                condition=Q(user__isnull=False, deleted=False),
                name="member_one_active_per_user",
            ),
        ]
        indexes = [models.Index(fields=["group", "server_seq"], name="member_group_seq")]

    def __str__(self):
        return self.display_name
