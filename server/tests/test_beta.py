"""Beta feedback and the anonymous usage counter (task 5.8, ADR 0019)."""

import uuid
from datetime import timedelta
from io import StringIO

import pytest
from django.core.management import call_command
from django.utils import timezone
from rest_framework.throttling import ScopedRateThrottle

from accounts.services import issue_tokens
from beta.models import Feedback, UsageDay

from .conftest import auth_client

pytestmark = pytest.mark.django_db

INSTALL = str(uuid.uuid4())


def today(offset=0):
    return timezone.now().date() + timedelta(days=offset)


def day(offset=0, manual=0, voice=0, receipt=0):
    return {"day": today(offset).isoformat(), "manual": manual, "voice": voice, "receipt": receipt}


def report(client, *days, install=INSTALL, version="0.1.0+1"):
    return client.post("/beta/usage", {"installId": install, "appVersion": version, "days": list(days)}, format="json")


def counts(install=INSTALL):
    return {(row.day, row.method): row.count for row in UsageDay.objects.filter(install_id=install)}


# --- Feedback ---


def test_feedback_is_stored_without_an_account(client):
    response = client.post(
        "/beta/feedback",
        {"message": "The mic button is hard to find", "contact": "sami@example.com", "appVersion": "0.1.0+1"},
        format="json",
    )

    assert response.status_code == 201
    feedback = Feedback.objects.get()
    assert (feedback.message, feedback.contact, feedback.app_version) == (
        "The mic button is hard to find",
        "sami@example.com",
        "0.1.0+1",
    )


def test_feedback_contact_is_optional(client):
    response = client.post("/beta/feedback", {"message": "Love it", "appVersion": "0.1.0+1"}, format="json")

    assert response.status_code == 201
    assert Feedback.objects.get().contact == ""


@pytest.mark.parametrize("message", ["", "   ", "x" * 2001])
def test_feedback_rejects_an_empty_or_too_long_message(client, message):
    response = client.post("/beta/feedback", {"message": message, "appVersion": "0.1.0+1"}, format="json")

    assert response.status_code == 400
    assert "message" in response.json()["fields"]
    assert not Feedback.objects.exists()


def test_a_bad_token_does_not_block_feedback(client):
    # The endpoints ignore authentication, so an expired session still sends.
    response = auth_client("not-a-token").post(
        "/beta/feedback", {"message": "Hi", "appVersion": "0.1.0+1"}, format="json"
    )

    assert response.status_code == 201


def test_feedback_is_throttled(client, monkeypatch):
    monkeypatch.setattr(ScopedRateThrottle, "THROTTLE_RATES", {"beta": "2/hour"})
    body = {"message": "Hi", "appVersion": "0.1.0+1"}

    statuses = [client.post("/beta/feedback", body, format="json").status_code for _ in range(3)]

    assert statuses == [201, 201, 429]


# --- Usage ---


def test_usage_stores_each_method_per_day(client):
    response = report(client, day(-1, manual=3, voice=1), day(0, receipt=2))

    assert response.status_code == 204
    assert counts() == {
        (today(-1), "manual"): 3,
        (today(-1), "voice"): 1,
        (today(-1), "receipt"): 0,
        (today(0), "manual"): 0,
        (today(0), "voice"): 0,
        (today(0), "receipt"): 2,
    }


def test_a_resent_day_replaces_its_counts(client):
    report(client, day(0, manual=2, voice=1))

    report(client, day(0, manual=1, voice=4))

    assert counts() == {(today(0), "manual"): 1, (today(0), "voice"): 4, (today(0), "receipt"): 0}


def test_installs_are_counted_apart(client):
    other = str(uuid.uuid4())
    report(client, day(0, manual=1))

    report(client, day(0, manual=5), install=other)

    assert counts()[(today(0), "manual")] == 1
    assert counts(other)[(today(0), "manual")] == 5


@pytest.mark.parametrize(
    "days",
    [
        [],
        [day(2)],
        [day(-61)],
        [day(0), day(0)],
        [day(0, manual=-1)],
        [day(0, voice=501)],
        [{"day": today().isoformat(), "manual": 1}],
        [day(-offset) for offset in range(32)],
    ],
    ids=["empty", "future", "too-old", "duplicate-day", "negative", "too-many", "missing-method", "too-many-days"],
)
def test_usage_rejects_bad_reports(client, days):
    response = report(client, *days)

    assert response.status_code == 400
    assert not UsageDay.objects.exists()


def test_tomorrow_is_allowed_for_phones_ahead_of_utc(client):
    assert report(client, day(1, manual=1)).status_code == 204


def test_usage_needs_a_valid_install_id(client):
    assert report(client, day(0, manual=1), install="phone-1").status_code == 400


def test_usage_is_never_tied_to_an_account(user):
    # Even sent with a valid session, a report stores no user.
    response = report(auth_client(issue_tokens(user)["access"]), day(0, manual=1))

    assert response.status_code == 204
    assert {field.name for field in UsageDay._meta.get_fields()} == {
        "id",
        "install_id",
        "day",
        "method",
        "count",
        "app_version",
        "updated_at",
    }


# --- Report ---


def test_beta_report_prints_usage_and_feedback(client):
    report(client, day(0, manual=2, voice=1))
    report(client, day(0, receipt=1), install=str(uuid.uuid4()))
    report(client, day(-1), install=str(uuid.uuid4()))
    client.post("/beta/feedback", {"message": "Dark mode please", "appVersion": "0.1.0+1"}, format="json")
    out = StringIO()

    call_command("beta_report", stdout=out)

    text = out.getvalue()
    assert "Installs sharing usage: 3 (reported in the last 7 days: 3)" in text
    assert f"{today().isoformat()}          2       2      1        1" in text
    # A day with nothing logged counts no installs.
    assert f"{today(-1).isoformat()}          0       0      0        0" in text
    assert "Dark mode please" in text
