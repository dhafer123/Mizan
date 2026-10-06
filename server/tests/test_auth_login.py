import uuid

import pytest
from rest_framework.throttling import ScopedRateThrottle

from accounts.models import Device, User

from .conftest import PASSWORD, auth_client

pytestmark = pytest.mark.django_db


def login(client, email="sami@example.com", password=PASSWORD, **extra):
    return client.post("/auth/login", {"email": email, "password": password, **extra}, format="json")


def test_returns_the_user_and_tokens(client, user):
    response = login(client)

    assert response.status_code == 200
    body = response.json()
    assert body["user"] == {"id": str(user.id), "email": "sami@example.com", "displayName": "Sami"}
    assert auth_client(body["access"]).get("/auth/me").status_code == 200
    user.refresh_from_db()
    assert user.last_login is not None


def test_email_case_and_spaces_dont_matter(client, user):
    assert login(client, email=" Sami@EXAMPLE.com ").status_code == 200


@pytest.mark.parametrize(
    ("email", "password"),
    [("sami@example.com", "wrong-password"), ("nobody@example.com", PASSWORD)],
)
def test_wrong_password_and_unknown_email_look_the_same(client, user, email, password):
    response = login(client, email=email, password=password)

    assert response.status_code == 401
    assert response.json() == {"code": "invalid_credentials", "detail": "Wrong email or password."}


def test_an_inactive_account_cannot_log_in(client, user):
    user.is_active = False
    user.save()

    response = login(client)

    assert response.status_code == 401
    assert response.json()["code"] == "invalid_credentials"


def test_the_password_is_not_trimmed(client, user):
    assert login(client, password=f" {PASSWORD} ").status_code == 401


def test_registers_or_refreshes_the_device(client, user):
    device_id = uuid.uuid4()

    login(client, device={"id": str(device_id), "platform": "android"})
    first_seen = Device.objects.get(id=device_id).last_seen_at
    login(client, device={"id": str(device_id), "platform": "android", "name": "Renamed"})

    device = Device.objects.get(id=device_id)
    assert Device.objects.count() == 1
    assert device.name == "Renamed"
    assert device.last_seen_at >= first_seen


def test_a_device_that_signs_in_to_another_account_moves_and_loses_its_push_token(client, user):
    device_id = uuid.uuid4()
    login(client, device={"id": str(device_id), "platform": "android"})
    Device.objects.filter(id=device_id).update(fcm_token="token-for-sami")
    User.objects.create_user(email="ali@example.com", password=PASSWORD)

    login(client, email="ali@example.com", device={"id": str(device_id), "platform": "android"})

    device = Device.objects.get(id=device_id)
    assert device.user.email == "ali@example.com"
    assert device.fcm_token == ""


def test_login_is_throttled_per_client(client, user, monkeypatch):
    monkeypatch.setattr(ScopedRateThrottle, "THROTTLE_RATES", {"auth": "3/min"})

    statuses = [login(client, password="wrong-password").status_code for _ in range(4)]

    assert statuses == [401, 401, 401, 429]
    response = login(client)
    assert response.status_code == 429
    assert response.json()["code"] == "throttled"
    assert "Retry-After" in response.headers
