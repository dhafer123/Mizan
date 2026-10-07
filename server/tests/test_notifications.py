"""Push notifications: device tokens, who gets told what, and dead tokens."""

import uuid

import pytest

from accounts.models import Device as DeviceRow
from accounts.models import User
from accounts.services import register_device
from notifications import delivery
from notifications.fcm import FcmSender
from notifications.services import settle_up_reminders

from . import ledger_factories as make
from .sync_helpers import DAY, Device, op

pytestmark = pytest.mark.django_db


class RecordingSender:
    def __init__(self):
        self.sent = []
        self.dead = set()

    def send(self, message):
        self.sent.append(message)
        return message["token"] not in self.dead

    def to(self, token):
        return [m for m in self.sent if m["token"] == token]


@pytest.fixture
def sender(monkeypatch, settings):
    settings.NOTIFICATIONS_INLINE = True
    recording = RecordingSender()
    monkeypatch.setattr(delivery, "get_sender", lambda: recording)
    return recording


@pytest.fixture
def ali(db):
    return User.objects.create_user(email="ali@example.com", password="x-long-password", display_name="Ali")


def phone(user, token):
    """A signed-in phone whose device row has a push token."""
    p = Device(user)
    register_device(user, id=p.id, platform="android")
    response = p.client.put(f"/auth/devices/{p.id}/push-token", {"token": token}, format="json")
    assert response.status_code == 204
    return p


@pytest.fixture
def flat(user, ali):
    g = make.group(user)
    return g, make.member(g, user, "Sami"), make.member(g, ali, "Ali")


def rent(g, payer, *members, entity_id=None):
    entity_id = entity_id or str(uuid.uuid4())
    shares = {m.entity_id: 300_000 for m in members}
    fields = {
        "id": entity_id, "groupId": g.entity_id, "payerId": payer.entity_id, "amountMinor": 900_000,
        "currency": "TND", "date": DAY, "split": {"type": "exact", "amounts": shares}, "shares": shares,
    }
    return op("shared_expenses", entity_id, "create", 0, **fields)


def test_a_push_token_belongs_to_one_of_my_devices(user, ali):
    mine = phone(user, "token-1")
    reinstalled = phone(user, "token-1")  # Same install token, new device row.

    not_mine = Device(ali).client.put(f"/auth/devices/{mine.id}/push-token", {"token": "x"}, format="json")

    assert not_mine.status_code == 404
    tokens = dict(DeviceRow.objects.values_list("id", "fcm_token"))
    assert (tokens[mine.id], tokens[reinstalled.id]) == ("", "token-1")


def test_a_new_shared_expense_notifies_the_others_and_syncs_my_other_phones(
    user, ali, flat, sender, django_capture_on_commit_callbacks
):
    g, sami, ali_member = flat
    me, _, _ = phone(user, "sami-phone"), phone(user, "sami-tablet"), phone(ali, "ali-phone")
    third = make.member(g, None, "Nour")
    expense = rent(g, sami, sami, ali_member, third)

    with django_capture_on_commit_callbacks(execute=True):
        assert me.one(expense)["status"] == "applied"
    with django_capture_on_commit_callbacks(execute=True):
        me.one(expense)  # A retry: already told.

    assert sender.to("sami-phone") == []
    (to_ali,) = sender.to("ali-phone")
    assert to_ali["notification"] == {"title": "Flat 4B", "body": "Sami paid 900.000 TND"}
    assert to_ali["data"] == {"type": "sync", "groupId": g.entity_id}
    (to_tablet,) = sender.to("sami-tablet")
    assert "notification" not in to_tablet and to_tablet["data"]["type"] == "sync"


def test_personal_changes_only_sync_my_other_phones(user, ali, flat, sender, django_capture_on_commit_callbacks):
    me, _, _ = phone(user, "sami-phone"), phone(user, "sami-tablet"), phone(ali, "ali-phone")
    eid = str(uuid.uuid4())

    with django_capture_on_commit_callbacks(execute=True):
        me.one(op("expenses", eid, "create", id=eid, amountMinor=4500, currency="TND", categoryId="food",
                  date=DAY, note=None, source="manual"))

    assert [m["token"] for m in sender.sent] == ["sami-tablet"]
    assert "notification" not in sender.sent[0]


def test_joining_notifies_the_members(user, ali, sender, django_capture_on_commit_callbacks):
    g = make.group(user)
    make.member(g, user, "Sami")
    sami, ali_phone = phone(user, "sami-phone"), phone(ali, "ali-phone")
    token = sami.client.post(f"/groups/{g.entity_id}/invites", format="json").json()["token"]

    with django_capture_on_commit_callbacks(execute=True):
        assert ali_phone.client.post(f"/groups/invites/{token}/join", format="json").status_code == 200

    (to_sami,) = sender.to("sami-phone")
    assert to_sami["notification"]["body"] == "Ali joined the group"
    assert "notification" not in sender.to("ali-phone")[0]


def test_weekly_reminder_goes_to_whoever_owes(user, ali, flat, sender, django_capture_on_commit_callbacks):
    g, sami, ali_member = flat
    phone(user, "sami-phone"), phone(ali, "ali-phone")
    make.shared_expense(g, sami, {sami.entity_id: 450_000, ali_member.entity_id: 450_000})
    make.settlement(g, ali_member, sami, 150_000)

    with django_capture_on_commit_callbacks(execute=True):
        assert settle_up_reminders() == 1

    (reminder,) = sender.sent
    assert reminder["token"] == "ali-phone"
    assert reminder["notification"]["body"] == "You owe 300.000 TND. Settle up when you can."


def test_a_dead_token_is_forgotten(user, ali, flat, sender, django_capture_on_commit_callbacks):
    g, sami, ali_member = flat
    me, _ = phone(user, "sami-phone"), phone(ali, "ali-phone")
    sender.dead.add("ali-phone")

    with django_capture_on_commit_callbacks(execute=True):
        me.one(rent(g, sami, sami, ali_member, make.member(g, None, "Nour")))

    assert DeviceRow.objects.get(user=ali).fcm_token == ""


def test_fcm_says_which_tokens_are_gone():
    class Response:
        def __init__(self, status, body):
            self.status_code, self.ok, self._body, self.text = status, status == 200, body, str(body)

        def json(self):
            return self._body

    unregistered = {"error": {"details": [{"errorCode": "UNREGISTERED"}]}}
    sender = FcmSender.__new__(FcmSender)
    sender._url = "https://fcm.example"
    results = []
    for status, body in [(200, {}), (404, {}), (400, unregistered), (500, {})]:
        sender._session = type("S", (), {"post": lambda self, *a, **k: Response(status, body)})()
        results.append(sender.send({"token": "t"}))

    assert results == [True, False, False, True]
