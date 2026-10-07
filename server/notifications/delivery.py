"""Getting pushes to phones: after the transaction commits, and off the
request thread, so `/sync/push` never waits on FCM."""

import logging
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from functools import cache

from django.conf import settings
from django.db import connection, transaction

from accounts.models import Device

from .fcm import FcmSender, LogSender

log = logging.getLogger(__name__)

# One worker: sends go out in order, and FCM is fast enough for this app's scale.
_executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="push")

# The app creates this Android channel; FCM shows background notifications in it.
ANDROID_CHANNEL = "groups"


@dataclass(frozen=True)
class Push:
    """What one account's phones get: always a "data changed" signal (the
    app syncs), and a visible notification when `title` is set."""

    user_id: int
    title: str = ""
    body: str = ""
    group_id: str = ""


@cache
def get_sender():
    if settings.FCM_CREDENTIALS_FILE:
        return FcmSender(settings.FCM_CREDENTIALS_FILE)
    return LogSender()


def send(pushes, *, except_device=None):
    """Sends `pushes` to every device of their accounts that has a push token,
    except `except_device` (the phone that made the change), once the current
    transaction commits."""
    pushes = list(pushes)
    if pushes:
        transaction.on_commit(lambda: _queue(pushes, except_device), robust=True)


def _queue(pushes, except_device):
    messages = _messages(pushes, except_device)
    if not messages:
        return
    if settings.NOTIFICATIONS_INLINE:
        _send_all(messages)
    else:
        _executor.submit(_send_in_background, messages)


def _messages(pushes, except_device):
    devices = Device.objects.filter(user_id__in={p.user_id for p in pushes}).exclude(fcm_token="")
    if except_device is not None:
        devices = devices.exclude(id=except_device)
    by_user = {}
    for device in devices:
        by_user.setdefault(device.user_id, []).append(device)
    return [(device, _message(device.fcm_token, push)) for push in pushes for device in by_user.get(push.user_id, [])]


def _message(token, push):
    data = {"type": "sync"}
    if push.group_id:
        data["groupId"] = push.group_id
    message = {
        "token": token,
        "data": data,
        "android": {"priority": "high"},
        "apns": {"payload": {"aps": {"content-available": 1}}},
    }
    if push.title:
        message["notification"] = {"title": push.title, "body": push.body}
        message["android"]["notification"] = {"channel_id": ANDROID_CHANNEL}
    return message


def _send_all(messages):
    sender = get_sender()
    for device, message in messages:
        if not sender.send(message):
            # Only if unchanged: the phone may have sent a new token meanwhile.
            Device.objects.filter(id=device.id, fcm_token=message["token"]).update(fcm_token="")


def _send_in_background(messages):
    try:
        _send_all(messages)
    except Exception:
        log.exception("Sending pushes failed")
    finally:
        connection.close()  # This thread's own connection.
