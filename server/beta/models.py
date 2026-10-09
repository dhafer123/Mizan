from django.db import models


class Feedback(models.Model):
    """A message from the in-app feedback button. Anonymous: no user, unless
    the sender left a contact to get a reply."""

    message = models.TextField(max_length=2000)
    contact = models.CharField(max_length=254, blank=True)
    app_version = models.CharField(max_length=32)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]


class UsageDay(models.Model):
    """How many expenses one install logged on one day with one input method.
    `install_id` is a random id the app makes when the user opts in (a new one
    after opting out and in again); it is not the account or the device id."""

    class Method(models.TextChoices):
        MANUAL = "manual"
        VOICE = "voice"
        RECEIPT = "receipt"

    install_id = models.UUIDField()
    day = models.DateField()
    method = models.CharField(max_length=16, choices=Method.choices)
    count = models.PositiveIntegerField()
    app_version = models.CharField(max_length=32)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["install_id", "day", "method"], name="usage_day_unique"),
        ]
