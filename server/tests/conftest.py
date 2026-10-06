import pytest
from django.core.cache import cache
from rest_framework.test import APIClient

from accounts.models import User

PASSWORD = "correct-horse-battery"


@pytest.fixture(autouse=True)
def _clear_cache():
    # Throttle counters live in the cache; each test starts with a full budget.
    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def client():
    return APIClient()


@pytest.fixture
def user(db):
    return User.objects.create_user(email="sami@example.com", password=PASSWORD, display_name="Sami")


def auth_client(access):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
    return client
