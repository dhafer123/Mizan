"""Refresh (rotation, reuse, revocation), logout, and using access tokens."""

import uuid
from datetime import timedelta

import pytest
from rest_framework_simplejwt.tokens import AccessToken, RefreshToken

from accounts.models import Device
from accounts.services import issue_tokens

from .conftest import auth_client

pytestmark = pytest.mark.django_db


def refresh(client, token):
    return client.post("/auth/refresh", {"refresh": token}, format="json")


def logout(client, token, **extra):
    return client.post("/auth/logout", {"refresh": token, **extra}, format="json")


# --- /auth/me and access tokens ---


def test_me_needs_a_token(client):
    response = client.get("/auth/me")

    assert response.status_code == 401
    assert response.json()["code"] == "not_authenticated"


def test_me_returns_the_signed_in_user(user):
    response = auth_client(issue_tokens(user)["access"]).get("/auth/me")

    assert response.json() == {"id": str(user.id), "email": "sami@example.com", "displayName": "Sami"}


def test_an_expired_access_token_is_token_not_valid(user):
    # The app refreshes when it sees this code.
    access = AccessToken.for_user(user)
    access.set_exp(lifetime=-timedelta(seconds=1))

    response = auth_client(str(access)).get("/auth/me")

    assert response.status_code == 401
    assert response.json()["code"] == "token_not_valid"


def test_a_refresh_token_is_not_an_access_token(user):
    response = auth_client(issue_tokens(user)["refresh"]).get("/auth/me")

    assert response.status_code == 401
    assert response.json()["code"] == "token_not_valid"


def test_changing_the_password_revokes_access_tokens(user):
    access = issue_tokens(user)["access"]
    user.set_password("a-brand-new-password")
    user.save()

    response = auth_client(access).get("/auth/me")

    assert response.status_code == 401
    assert response.json()["code"] == "password_changed"


# --- /auth/refresh ---


def test_refresh_returns_a_new_pair(client, user):
    tokens = issue_tokens(user)

    response = refresh(client, tokens["refresh"])

    assert response.status_code == 200
    new = response.json()
    assert set(new) == {"access", "refresh"}
    assert new["refresh"] != tokens["refresh"]
    assert auth_client(new["access"]).get("/auth/me").status_code == 200


def test_a_refresh_token_works_only_once(client, user):
    tokens = issue_tokens(user)
    assert refresh(client, tokens["refresh"]).status_code == 200

    response = refresh(client, tokens["refresh"])

    assert response.status_code == 401
    assert response.json()["code"] == "token_not_valid"


def test_the_rotated_token_keeps_working(client, user):
    token = issue_tokens(user)["refresh"]
    for _ in range(3):
        response = refresh(client, token)
        assert response.status_code == 200
        token = response.json()["refresh"]


@pytest.mark.parametrize("token", ["", "garbage", "a.b.c"])
def test_malformed_refresh_tokens(client, token):
    response = refresh(client, token)

    assert response.status_code in (400, 401)
    assert response.json()["code"] in ("invalid", "token_not_valid")


def test_an_expired_refresh_token(client, user):
    token = RefreshToken.for_user(user)
    token.set_exp(lifetime=-timedelta(seconds=1))

    response = refresh(client, str(token))

    assert response.status_code == 401
    assert response.json()["code"] == "token_not_valid"


def test_an_access_token_cannot_refresh(client, user):
    assert refresh(client, issue_tokens(user)["access"]).status_code == 401


def test_refresh_fails_for_a_deleted_account(client, user):
    token = issue_tokens(user)["refresh"]
    user.delete()

    response = refresh(client, token)

    assert response.status_code == 401
    assert response.json()["code"] == "token_not_valid"


def test_refresh_fails_for_an_inactive_account(client, user):
    token = issue_tokens(user)["refresh"]
    user.is_active = False
    user.save()

    assert refresh(client, token).status_code == 401


def test_refresh_fails_after_a_password_change(client, user):
    token = issue_tokens(user)["refresh"]
    user.set_password("a-brand-new-password")
    user.save()

    assert refresh(client, token).status_code == 401


# --- /auth/logout ---


def test_logout_revokes_the_refresh_token(client, user):
    token = issue_tokens(user)["refresh"]

    assert logout(client, token).status_code == 204
    assert refresh(client, token).status_code == 401


def test_logout_forgets_the_device(client, user):
    device_id = uuid.uuid4()
    client.post(
        "/auth/login",
        {"email": user.email, "password": "correct-horse-battery", "device": {"id": str(device_id), "platform": "android"}},
        format="json",
    )
    token = issue_tokens(user)["refresh"]

    assert logout(client, token, deviceId=str(device_id)).status_code == 204
    assert not Device.objects.filter(id=device_id).exists()


def test_logout_cannot_remove_another_users_device(client, user, django_user_model):
    other = django_user_model.objects.create_user(email="ali@example.com", password="x-long-password")
    device = Device.objects.create(id=uuid.uuid4(), user=other, platform="android", last_seen_at="2026-10-06T00:00Z")

    logout(client, issue_tokens(user)["refresh"], deviceId=str(device.id))

    assert Device.objects.filter(id=device.id).exists()


def test_logout_is_idempotent(client, user):
    token = issue_tokens(user)["refresh"]

    assert logout(client, token).status_code == 204
    assert logout(client, token).status_code == 204
    assert logout(client, "garbage").status_code == 204
