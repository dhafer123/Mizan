from django.conf import settings
from django.db import models
from django.db.models import Q

from groups.models import Group


class AppliedOp(models.Model):
    """Every op the server has processed, with the result it returned, so a
    retried push gets the same answer and changes nothing (§6, idempotency).

    Keyed by (user, op_id), not op_id alone: another user sending the same
    op id must not read back this user's result. Insert-only (trigger).
    """

    class OpType(models.TextChoices):
        CREATE = "create"
        UPDATE = "update"
        DELETE = "delete"

    class Status(models.TextChoices):
        APPLIED = "applied"
        MERGED = "merged"
        REJECTED = "rejected"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+")
    op_id = models.UUIDField()
    entity = models.CharField(max_length=32)
    entity_id = models.CharField(max_length=64)
    op_type = models.CharField(max_length=8, choices=OpType.choices)
    status = models.CharField(max_length=8, choices=Status.choices)
    # Why it was rejected (e.g. `not_a_member`); empty otherwise.
    reason = models.CharField(max_length=64, blank=True)
    # The per-op result as first returned, replayed verbatim on a retry.
    result = models.JSONField()
    applied_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["user", "op_id"], name="applied_op_user_op_id_unique"),
            models.CheckConstraint(
                condition=Q(status="rejected") | Q(reason=""), name="applied_op_reason_only_when_rejected"
            ),
        ]


class EntityHistory(models.Model):
    """Field-level change log, pulled by the app ("Ali changed amount 120 → 150").

    One row per changed field, including edits that lost a conflict (kind
    `overwritten`) and deletes, so nothing is lost silently (§6, "no lost
    writes"). Insert-only; `server_seq` comes from the same sequence as the
    entities, so a pull returns history in the same pass.

    Scope for pull: `owner` for personal entities, `group` for group ones.
    """

    class Kind(models.TextChoices):
        CREATED = "created"
        CHANGED = "changed"
        # A same-field conflict: this value was replaced by a later edit.
        OVERWRITTEN = "overwritten"
        DELETED = "deleted"
        RESTORED = "restored"
        # An edit that arrived after the row was deleted: delete wins (§6),
        # and the edit's values are kept here.
        DISCARDED = "discarded"

    entity = models.CharField(max_length=32)
    entity_id = models.CharField(max_length=64)
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.CASCADE, related_name="+"
    )
    group = models.ForeignKey(Group, null=True, blank=True, on_delete=models.CASCADE, related_name="+")
    kind = models.CharField(max_length=16, choices=Kind.choices)
    # Empty for a whole-row event (created, deleted, restored).
    field = models.CharField(max_length=64, blank=True)
    old_value = models.JSONField(null=True, blank=True)
    new_value = models.JSONField(null=True, blank=True)
    changed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    op_id = models.UUIDField(null=True, blank=True)
    # The device that sent the op. Push compares it to tell a concurrent edit
    # (another device) from this device's own earlier op.
    device_id = models.UUIDField(null=True, blank=True)
    # The entity's version after this change. Push uses it to find the fields
    # changed since an op's baseVersion (same-field conflicts).
    version = models.PositiveIntegerField(null=True, blank=True)
    server_seq = models.BigIntegerField(unique=True, editable=False)
    changed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name_plural = "entity history"
        constraints = [
            # Exactly one scope.
            models.CheckConstraint(
                condition=Q(owner__isnull=False, group__isnull=True) | Q(owner__isnull=True, group__isnull=False),
                name="history_one_scope",
            ),
        ]
        indexes = [
            models.Index(fields=["owner", "server_seq"], name="history_owner_seq"),
            models.Index(fields=["group", "server_seq"], name="history_group_seq"),
            models.Index(fields=["entity", "entity_id", "version"], name="history_entity_version"),
        ]

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        self.refresh_from_db(fields=["server_seq"])
