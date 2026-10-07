"""Sending through FCM's HTTP v1 API with a Firebase service-account key."""

import logging

import requests
from google.auth.transport.requests import AuthorizedSession
from google.oauth2 import service_account

SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

log = logging.getLogger(__name__)


class FcmSender:
    def __init__(self, credentials_file):
        credentials = service_account.Credentials.from_service_account_file(credentials_file, scopes=[SCOPE])
        self._url = f"https://fcm.googleapis.com/v1/projects/{credentials.project_id}/messages:send"
        # Fetches and refreshes the OAuth access token itself.
        self._session = AuthorizedSession(credentials)

    def send(self, message):
        """Sends one FCM `message`. False when its token is no longer valid
        (the app was uninstalled, or the token was replaced), so the device
        should forget it. Other failures are logged: a push is only a hint
        to sync, and the app syncs on its own anyway."""
        try:
            response = self._session.post(self._url, json={"message": message}, timeout=10)
        except requests.RequestException as e:
            log.warning("FCM send failed: %s", e)
            return True
        if response.ok:
            return True
        if response.status_code == 404 or _error_code(response) == "UNREGISTERED":
            return False
        log.warning("FCM send failed: %s %s", response.status_code, response.text[:500])
        return True


class LogSender:
    """Used when no Firebase key is configured (local development)."""

    def send(self, message):
        log.info("Push (not sent, FCM_CREDENTIALS_FILE unset): %s", {k: v for k, v in message.items() if k != "token"})
        return True


def _error_code(response):
    try:
        details = response.json()["error"].get("details", [])
    except (ValueError, KeyError, AttributeError):
        return None
    return next((d.get("errorCode") for d in details if isinstance(d, dict) and "errorCode" in d), None)
