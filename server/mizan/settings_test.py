"""Settings for pytest: the normal settings, plus a throwaway key and fast hashing."""

import os

os.environ.setdefault("DJANGO_SECRET_KEY", "test-only-not-a-secret")

from .settings import *  # noqa: E402,F403

PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]
