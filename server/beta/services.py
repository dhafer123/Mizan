from datetime import timedelta

from django.db import transaction
from django.db.models import Count, Max, Sum
from django.utils import timezone

from .models import Feedback, UsageDay


def send_feedback(*, message, contact, app_version):
    return Feedback.objects.create(message=message, contact=contact, app_version=app_version)


@transaction.atomic
def record_usage(*, install_id, app_version, days):
    """Stores one install's counts. A report replaces what was there for the
    same days, so the app can resend recent days as they change (an expense
    deleted, a late sync) and the counts stay right."""
    for entry in days:
        for method in UsageDay.Method.values:
            UsageDay.objects.update_or_create(
                install_id=install_id,
                day=entry["day"],
                method=method,
                defaults={"count": entry[method], "app_version": app_version},
            )


def usage_summary(days=14):
    """Per day, newest first: installs that logged something, and expenses by method."""
    since = timezone.now().date() - timedelta(days=days - 1)
    recent = UsageDay.objects.filter(day__gte=since)
    summary = {}
    for row in recent.values("day", "method").annotate(total=Sum("count")):
        summary.setdefault(row["day"], {})[row["method"]] = row["total"]
    for row in recent.filter(count__gt=0).values("day").annotate(installs=Count("install_id", distinct=True)):
        summary[row["day"]]["installs"] = row["installs"]
    return dict(sorted(summary.items(), reverse=True))


def install_counts():
    """(installs that ever reported, installs that reported a day in the last 7)."""
    week = timezone.now().date() - timedelta(days=6)
    per_install = UsageDay.objects.values("install_id").annotate(last=Max("day"))
    return per_install.count(), per_install.filter(last__gte=week).count()
