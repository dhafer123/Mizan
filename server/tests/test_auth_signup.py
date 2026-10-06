import uuid

import pytest

from accounts.models import Device, User

from .conftest import PASSWORD, auth_client

pytestmark = pytest.mark.django_db


def signup(client, **overrides):
    body = {"email": "ali@example.com", "password": PASSWORD, "displayName": "Ali", **overrides}
    return client.post("/auth/signup", body, format="json")


def field_codes(response, field):
    return [error["code"] for error in response.json()["fields"][field]]


def test_creates_the_account_and_signs_it_in(client):
    response = signup(client)

    assert response.status_code == 201
    body = response.json()
    user = User.objects.get(email="ali@example.com")
    assert body["user"] == {"id": str(user.id), "email": "ali@example.com", "displayName": "Ali"}
    assert user.check_password(PASSWORD)
    assert user.last_login is not None
    # The tokens work straight away.
    assert auth_client(body["access"]).get("/auth/me").json()["email"] == "ali@example.com"
    assert client.post("/auth/refresh", {"refresh": body["refresh"]}, format="json").status_code == 200


def test_email_is_trimmed_and_lowercased(client):
    response = signup(client, email="  Ali@Example.COM ")

    assert response.status_code == 201
    assert response.json()["user"]["email"] == "ali@example.com"


def test_display_name_is_optional(client):
    response = client.post("/auth/signup", {"email": "ali@example.com", "password": PASSWORD}, format="json")

    assert response.status_code == 201
    assert response.json()["user"]["displayName"] == ""


def test_an_email_can_only_be_used_once_ignoring_case(client, user):
    response = signup(client, email="SAMI@example.com")

    assert response.status_code == 400
    assert response.json()["code"] == "invalid"
    assert field_codes(response, "email") == ["email_taken"]
    assert User.objects.count() == 1


@pytest.mark.parametrize(
    ("password", "code"),
    [
        ("short1!", "password_too_short"),
        ("password123", "password_too_common"),
        ("4815162342815", "password_entirely_numeric"),
        ("ali@example.com", "password_too_similar"),
    ],
)
def test_weak_passwords_are_rejected_with_a_reason(client, password, code):
    response = signup(client, password=password)

    assert response.status_code == 400
    assert code in field_codes(response, "password")
    assert not User.objects.exists()


@pytest.mark.parametrize(
    ("body", "field", "code"),
    [
        ({"email": "not-an-email"}, "email", "invalid"),
        ({"email": ""}, "email", "blank"),
        ({"password": ""}, "password", "blank"),
        ({"displayName": "x" * 51}, "displayName", "max_length"),
    ],
)
def test_invalid_fields(client, body, field, code):
    response = signup(client, **body)

    assert response.status_code == 400
    assert field_codes(response, field) == [code]


def test_missing_fields(client):
    response = client.post("/auth/signup", {}, format="json")

    assert response.status_code == 400
    assert set(response.json()["fields"]) == {"email", "password"}


def test_registers_the_device(client):
    device_id = uuid.uuid4()

    response = signup(client, device={"id": str(device_id), "platform": "android", "name": "Pixel 8"})

    assert response.status_code == 201
    device = Device.objects.get(id=device_id)
    assert (device.user.email, device.platform, device.name) == ("ali@example.com", "android", "Pixel 8")


def test_a_bad_device_fails_the_whole_sign_up(client):
    response = signup(client, device={"id": "nope", "platform": "windows"})

    assert response.status_code == 400
    assert set(response.json()["fields"]) == {"device.id", "device.platform"}
    assert not User.objects.exists()
