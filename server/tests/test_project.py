"""Smoke tests for the project skeleton (task 3.1)."""

from io import StringIO

import pytest
from django.apps import apps
from django.conf import settings
from django.core.management import call_command
from django.db import DatabaseError, connection
from rest_framework.test import APIClient

SERVER_APPS = ["accounts", "ledger", "sync", "groups", "notifications"]


def test_all_server_apps_are_installed():
    for label in SERVER_APPS:
        assert apps.is_installed(label), label


def test_custom_user_model():
    assert settings.AUTH_USER_MODEL == "accounts.User"


@pytest.mark.django_db
def test_database_is_postgres():
    # server_seq (task 3.3) relies on a Postgres sequence; never fall back to SQLite.
    assert connection.vendor == "postgresql"


@pytest.mark.django_db
def test_models_and_migrations_are_in_sync():
    out = StringIO()
    call_command("makemigrations", "--check", "--dry-run", stdout=out)
    assert "No changes detected" in out.getvalue()


@pytest.mark.django_db
def test_health_is_public_and_reports_ok():
    response = APIClient().get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.django_db
def test_health_reports_503_when_the_database_is_down(monkeypatch):
    def fail():
        raise DatabaseError("down")

    monkeypatch.setattr(connection, "ensure_connection", fail)

    response = APIClient().get("/health")

    assert response.status_code == 503
    assert response.json()["database"] == "unreachable"
