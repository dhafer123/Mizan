"""Account rules: sign-up, login, token refresh, logout and devices.

Views only parse input and shape output; everything that decides is here.
"""

from django.contrib.auth import authenticate
from django.contrib.auth.models import update_last_login
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError, transaction
from django.utils import timezone
from rest_framework import status
from rest_framework.exceptions import APIException, ErrorDetail, ValidationError
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.settings import api_settings as jwt_settings
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.utils import get_md5_hash_password

from .models import Device, User, normalize_email


class InvalidCredentials(APIException):
    # A plain APIException: DRF turns AuthenticationFailed into a 403 on views
    # without an authentication class, and login has none.
    status_code = status.HTTP_401_UNAUTHORIZED
    default_code = "invalid_credentials"
    default_detail = "Wrong email or password."


class InvalidRefreshToken(APIException):
    # Same code as simplejwt's InvalidToken (which, being an AuthenticationFailed,
    # would also become a 403 here), so the app handles one code for both.
    status_code = status.HTTP_401_UNAUTHORIZED
    default_code = "token_not_valid"
    default_detail = "Token is invalid or expired."


def _email_taken():
    return ValidationError(
        {"email": [ErrorDetail("An account with this email already exists.", code="email_taken")]}
    )


def issue_tokens(user):
    refresh = RefreshToken.for_user(user)
    return {"access": str(refresh.access_token), "refresh": str(refresh)}


@transaction.atomic
def sign_up(*, email, password, display_name="", device=None):
    """Creates an account and signs it in. Returns (user, tokens)."""
    email = normalize_email(email)
    if User.objects.filter(email=email).exists():
        raise _email_taken()
    try:
        validate_password(password, user=User(email=email, display_name=display_name))
    except DjangoValidationError as e:
        raise ValidationError(
            {"password": [ErrorDetail(" ".join(err.messages), code=err.code) for err in e.error_list]}
        ) from e
    try:
        with transaction.atomic():
            user = User.objects.create_user(email=email, password=password, display_name=display_name)
    except IntegrityError as e:  # Lost a race with another sign-up for the same email.
        raise _email_taken() from e
    return user, _start_session(user, device)


@transaction.atomic
def log_in(request, *, email, password, device=None):
    """Returns (user, tokens). An unknown email, a wrong password and an
    inactive account give the same error, so it doesn't reveal which emails exist."""
    user = authenticate(request, username=normalize_email(email), password=password)
    if user is None:
        raise InvalidCredentials()
    return user, _start_session(user, device)


def _start_session(user, device):
    if device:
        register_device(user, **device)
    update_last_login(None, user)
    return issue_tokens(user)


def register_device(user, *, id, platform, name=""):
    """Adds or refreshes a device. A phone that signs in to another account
    moves to it and loses its push token, which belonged to the old account."""
    defaults = {"user": user, "platform": platform, "name": name, "last_seen_at": timezone.now()}
    if Device.objects.filter(id=id).exclude(user=user).exists():
        defaults["fcm_token"] = ""
    device, _ = Device.objects.update_or_create(id=id, defaults=defaults)
    return device


class DeviceNotFound(APIException):
    status_code = status.HTTP_404_NOT_FOUND
    default_code = "device_not_found"
    default_detail = "This device isn't signed in to this account."


@transaction.atomic
def set_push_token(user, device_id, token):
    """Stores the device's FCM token ("" stops pushes to it). A token belongs
    to one install: if another device row had it (a reinstall), it moves."""
    device = Device.objects.select_for_update().filter(id=device_id, user=user).first()
    if device is None:
        raise DeviceNotFound()
    if token:
        Device.objects.filter(fcm_token=token).exclude(id=device_id).update(fcm_token="")
    device.fcm_token = token
    device.last_seen_at = timezone.now()
    device.save(update_fields=["fcm_token", "last_seen_at"])


def refresh_tokens(raw_refresh):
    """Swaps a refresh token for a new access + refresh pair.

    Each refresh token works once. Reusing one, or sending a revoked, expired
    or malformed one, is `InvalidRefreshToken` (401), and the app then signs out.
    """
    try:
        token = RefreshToken(raw_refresh)  # Checks signature, expiry, type and the blacklist.
    except TokenError as e:
        raise InvalidRefreshToken(str(e)) from e
    user = User.objects.filter(pk=token.get(jwt_settings.USER_ID_CLAIM), is_active=True).first()
    if user is None:
        raise InvalidRefreshToken("No active account for this token.")
    if token.get(jwt_settings.REVOKE_TOKEN_CLAIM) != get_md5_hash_password(user.password):
        raise InvalidRefreshToken("The password has changed. Sign in again.")
    with transaction.atomic():
        # get_or_create on a one-to-one: of two concurrent refreshes with the
        # same token, only one creates the blacklist row and gets new tokens.
        _, created = token.blacklist()
        if not created:
            raise InvalidRefreshToken("Token is blacklisted")
        return issue_tokens(user)


@transaction.atomic
def log_out(*, raw_refresh, device_id=None):
    """Revokes the refresh token and forgets the device (no more pushes to it).
    An already invalid token is fine: there is nothing left to revoke."""
    try:
        token = RefreshToken(raw_refresh)
    except TokenError:
        return
    token.blacklist()
    if device_id:
        Device.objects.filter(id=device_id, user_id=token.get(jwt_settings.USER_ID_CLAIM)).delete()
