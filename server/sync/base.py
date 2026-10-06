from django.conf import settings
from django.db import models
from django.db.models import Q


class SyncedModel(models.Model):
    """Sync metadata shared by every synced entity (ARCHITECTURE.md §4, §6).

    `entity_id` is the client's id (UUIDv7, or a fixed id such as `food` or
    `budget-2026-10` for personal rows; ADRs 0001, 0002). Django reserves the
    name `id` for the primary key, which here is a server-only surrogate.

    `version` and `server_seq` are set by a database trigger on every write
    (see `sync/db.py`); Python never sets them. `save()` reads them back.
    """

    entity_id = models.CharField(max_length=64)
    version = models.PositiveIntegerField(default=0, editable=False)
    deleted = models.BooleanField(default=False)
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    # Not null in the database: the trigger fills it before the check runs.
    server_seq = models.BigIntegerField(unique=True, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        self.refresh_from_db(fields=["version", "server_seq"])


def currency_check(name):
    return models.CheckConstraint(condition=Q(currency__regex=r"^[A-Z]{3}$"), name=name)
