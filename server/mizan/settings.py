"""Django settings for the Mizan server.

All configuration comes from environment variables (see `.env.example`).
"""

import os
from datetime import timedelta
from pathlib import Path

from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent


def env(name, default=None):
    value = os.environ.get(name)
    return default if value in (None, "") else value


def env_bool(name, default=False):
    return env(name, "1" if default else "0").lower() in ("1", "true", "yes", "on")


def env_list(name, default=""):
    return [item.strip() for item in env(name, default).split(",") if item.strip()]


DEBUG = env_bool("DJANGO_DEBUG")

SECRET_KEY = env("DJANGO_SECRET_KEY")
if not SECRET_KEY:
    if not DEBUG:
        raise ImproperlyConfigured("Set DJANGO_SECRET_KEY (or DJANGO_DEBUG=1 for local development).")
    SECRET_KEY = "django-insecure-local-development-only"

# 10.0.2.2 is this machine as seen from the Android emulator.
ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1,10.0.2.2" if DEBUG else "")

INSTALLED_APPS = [
    "django.contrib.contenttypes",
    "django.contrib.auth",
    "rest_framework",
    "rest_framework_simplejwt.token_blacklist",
    "accounts",
    "ledger",
    "sync",
    "groups",
    "notifications",
]

# API only: no sessions, CSRF cookies or templates. Auth is JWT.
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "mizan.urls"
WSGI_APPLICATION = "mizan.wsgi.application"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": env("POSTGRES_DB", "mizan"),
        "USER": env("POSTGRES_USER", "mizan"),
        "PASSWORD": env("POSTGRES_PASSWORD", "mizan"),
        "HOST": env("POSTGRES_HOST", "localhost"),
        "PORT": env("POSTGRES_PORT", "5432"),
        # Each sync op runs in its own explicit transaction (§6), not one per request.
        "ATOMIC_REQUESTS": False,
        # Persistent connections only with a fixed pool of worker threads. The
        # dev server (and anything thread-per-request) leaks one per thread
        # and runs Postgres out of slots; the sync simulation hit that. 0 =
        # close after each request (Django's default).
        "CONN_MAX_AGE": int(env("DJANGO_CONN_MAX_AGE", "0")),
        "CONN_HEALTH_CHECKS": True,
    }
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
AUTH_USER_MODEL = "accounts.User"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = False
USE_TZ = True

REST_FRAMEWORK = {
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "DEFAULT_PARSER_CLASSES": ["rest_framework.parsers.JSONParser"],
    # Closed by default; endpoints that don't need a user opt out explicitly.
    "DEFAULT_AUTHENTICATION_CLASSES": ["rest_framework_simplejwt.authentication.JWTAuthentication"],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "EXCEPTION_HANDLER": "mizan.errors.api_exception_handler",
    # Password guessing: login and sign-up share one per-IP budget.
    "DEFAULT_THROTTLE_RATES": {"auth": env("AUTH_THROTTLE_RATE", "20/min")},
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=15),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=30),
    # Refresh is handled by accounts.services.refresh_tokens, which rotates and
    # blacklists the old refresh token itself; these keep simplejwt consistent.
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    # Tokens carry a hash of the password, so changing it signs out every device.
    "CHECK_REVOKE_TOKEN": True,
    "AUTH_HEADER_TYPES": ("Bearer",),
    "USER_ID_FIELD": "id",
    "USER_ID_CLAIM": "user_id",
}

# Push notifications (task 4.6): a Firebase service-account key (JSON file).
# Unset, pushes are only logged; the app still syncs on its own triggers.
FCM_CREDENTIALS_FILE = env("FCM_CREDENTIALS_FILE")
# Send pushes on the request thread (tests) instead of a background one.
NOTIFICATIONS_INLINE = env_bool("NOTIFICATIONS_INLINE")

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "root": {"handlers": ["console"], "level": env("DJANGO_LOG_LEVEL", "INFO")},
}
