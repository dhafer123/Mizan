"""Groups through push, invites (valid, expired, reused), joining and claiming placeholders."""

import uuid
from datetime import timedelta

import pytest
from django.utils import timezone

from accounts.models import User
from groups.models import GroupInvite, Member

from . import ledger_factories as make
from .sync_helpers import Device, create_expense, op

pytestmark = pytest.mark.django_db


@pytest.fixture
def ali(db):
    return User.objects.create_user(email="ali@example.com", password="x-long-password", display_name="Ali")


@pytest.fixture
def flat(user):
    """Sami's group, with a placeholder for Ali."""
    g = make.group(user)
    return g, make.member(g, user, "Sami"), make.member(g, None, "Ali")


def invite(device, group, member=None):
    body = {"memberId": member.entity_id} if member else {}
    return device.client.post(f"/groups/{group.entity_id}/invites", body, format="json")


def join(device, token):
    return device.client.post(f"/groups/invites/{token}/join", format="json")


# --- Creating a group through push ---


def test_the_creator_founds_a_group_offline_and_adds_placeholders(user):
    phone = Device(user)
    gid, me, ali = str(uuid.uuid4()), str(uuid.uuid4()), str(uuid.uuid4())

    results = phone.push(
        op("groups", gid, "create", id=gid, name="Flat 4B", currency="TND"),
        op("members", me, "create", id=me, groupId=gid, userId=str(user.pk), displayName="Sami"),
        op("members", ali, "create", id=ali, groupId=gid, userId=None, displayName="Ali"),
    )

    assert [r["status"] for r in results] == ["applied"] * 3
    pulled = phone.client.get("/sync/pull").json()["changes"]
    members = {c["state"]["id"]: c["state"]["userId"] for c in pulled if c["entity"] == "members"}
    assert members == {me: str(user.pk), ali: None}


def test_push_never_puts_a_user_in_a_group(user, ali, flat):
    g, _, placeholder = flat
    sami, intruder = Device(user), Device(ali)
    mid = str(uuid.uuid4())

    # Ali can't add himself, and Sami can't claim the placeholder for Ali.
    sneak_in = intruder.one(op("members", mid, "create", id=mid, groupId=g.entity_id, userId=str(ali.pk), displayName="Ali"))
    claim = sami.one(op("members", placeholder.entity_id, base=placeholder.version, userId=str(ali.pk)))

    assert sneak_in["reason"] == "not_a_member"
    assert (claim["reason"], claim["field"]) == ("invalid_field", "userId")
    assert not Member.objects.filter(user=ali).exists()


# --- Invites ---


def test_a_valid_invite_adds_a_new_member_who_can_backfill_the_group(user, ali, flat):
    g, sami_member, _ = flat
    make.shared_expense(g, sami_member, {sami_member.entity_id: 9000})  # Before Ali joins.
    sami, phone = Device(user), Device(ali)
    create_expense(phone)
    cursor = phone.client.get("/sync/pull").json()["cursor"]  # Ali's phone is past the group's rows.

    token = invite(sami, g).json()["token"]
    preview = phone.client.get(f"/groups/invites/{token}").json()
    joined = join(phone, token)

    assert (preview["groupName"], preview["memberName"], preview["invitedBy"]) == ("Flat 4B", None, "Sami")
    assert joined.status_code == 200
    member = Member.objects.get(entity_id=joined.json()["memberId"])
    assert (member.user, member.display_name, member.group) == (ali, "Ali", g)
    # A normal pull brings only what changed after the cursor: the new member row.
    later = phone.client.get(f"/sync/pull?since={cursor}").json()["changes"]
    assert {c["entity"] for c in later} == {"members", "entity_history"}
    # The group-scoped pull brings the whole group, older rows included.
    backfill = phone.client.get(f"/sync/pull?group={g.entity_id}").json()["changes"]
    assert {c["entity"] for c in backfill} >= {"groups", "members", "shared_expenses"}


def test_an_expired_invite_is_refused(user, ali, flat):
    g = flat[0]
    token = invite(Device(user), g).json()["token"]
    GroupInvite.objects.filter(token=token).update(expires_at=timezone.now() - timedelta(seconds=1))

    response = join(Device(ali), token)

    assert (response.status_code, response.json()["code"]) == (410, "invite_expired")
    assert not Member.objects.filter(user=ali).exists()


def test_an_invite_works_once_but_its_user_can_retry(user, ali, flat):
    g = flat[0]
    token = invite(Device(user), g).json()["token"]
    other = User.objects.create_user(email="mehdi@example.com", password="x-long-password")

    first = join(Device(ali), token)
    retry = join(Device(ali), token)  # The first answer was lost.
    reused = join(Device(other), token)

    assert retry.json() == first.json()
    assert (reused.status_code, reused.json()["code"]) == (409, "invite_used")
    assert Member.objects.filter(group=g, user=ali).count() == 1
    assert not Member.objects.filter(user=other).exists()


def test_only_members_create_invites_and_members_cannot_join_twice(user, ali, flat):
    g = flat[0]
    sami = Device(user)

    outsider = invite(Device(ali), g)
    again = join(sami, invite(sami, g).json()["token"])

    assert (outsider.status_code, outsider.json()["code"]) == (404, "group_not_found")
    assert (again.status_code, again.json()["code"]) == (409, "already_member")


# --- Claiming a placeholder ---


def test_joining_with_a_placeholder_invite_claims_it(user, ali, flat):
    g, sami_member, placeholder = flat
    make.shared_expense(g, sami_member, {sami_member.entity_id: 4500, placeholder.entity_id: 4500})
    sami, phone = Device(user), Device(ali)
    token = invite(sami, g, placeholder).json()["token"]

    assert phone.client.get(f"/groups/invites/{token}").json()["memberName"] == "Ali"
    joined = join(phone, token).json()

    # Ali *is* the placeholder now: same member, so its expenses are his.
    assert joined == {"groupId": g.entity_id, "memberId": placeholder.entity_id}
    placeholder.refresh_from_db()
    assert placeholder.user == ali
    assert Member.objects.filter(group=g).count() == 2
    # Sami's phone pulls the claim, with history.
    changes = sami.client.get("/sync/pull").json()["changes"]
    claimed = [c["state"] for c in changes if c["entity"] == "members" and c["state"]["id"] == placeholder.entity_id]
    assert claimed[-1]["userId"] == str(ali.pk)
    assert any(c["state"].get("field") == "userId" for c in changes if c["entity"] == "entity_history")


def test_a_claimed_placeholder_cannot_be_claimed_again(user, ali, flat):
    g, _, placeholder = flat
    sami = Device(user)
    first, second = invite(sami, g, placeholder).json()["token"], invite(sami, g, placeholder).json()["token"]
    join(Device(ali), first)
    other = User.objects.create_user(email="mehdi@example.com", password="x-long-password")

    late = join(Device(other), second)
    new_invite = invite(sami, g, placeholder)

    assert (late.status_code, late.json()["code"]) == (409, "placeholder_taken")
    assert (new_invite.status_code, new_invite.json()["code"]) == (400, "not_a_placeholder")
