"""Invites, joining and claiming placeholders (task 4.1, ARCHITECTURE.md §9).

Groups and members are created by sync push like any synced row (the group's
creator adds themselves as its first member). Everyone else gets in here: a
member creates an invite, and whoever opens it joins. An invite is random,
expires after `INVITE_TTL`, and works once. If it names a placeholder member,
joining claims that placeholder (it keeps its expenses and balance);
otherwise joining adds a new member.

Joining writes a member row like push does: under the ledger lock, with
history, so other members' phones pull the change and the joiner's phone
can backfill the group (`/sync/pull?group=`).
"""

import secrets
import uuid
from datetime import timedelta

from django.db import transaction
from django.utils import timezone
from rest_framework import status
from rest_framework.exceptions import APIException

from notifications.services import joined
from sync.db import lock_ledger
from sync.models import EntityHistory

from .models import Group, GroupInvite, Member

INVITE_TTL = timedelta(days=7)


class _GroupError(APIException):
    def __init__(self):
        super().__init__(self.default_detail, self.default_code)


class GroupNotFound(_GroupError):
    # Also for groups the user isn't in: don't reveal they exist.
    status_code = status.HTTP_404_NOT_FOUND
    default_code = "group_not_found"
    default_detail = "No such group."


class NotAPlaceholder(_GroupError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "not_a_placeholder"
    default_detail = "Only a placeholder member can be claimed with an invite."


class InviteNotFound(_GroupError):
    status_code = status.HTTP_404_NOT_FOUND
    default_code = "invite_not_found"
    default_detail = "This invite doesn't exist."


class InviteExpired(_GroupError):
    status_code = status.HTTP_410_GONE
    default_code = "invite_expired"
    default_detail = "This invite has expired."


class InviteUsed(_GroupError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "invite_used"
    default_detail = "This invite was already used."


class AlreadyMember(_GroupError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "already_member"
    default_detail = "You're already in this group."


class PlaceholderTaken(_GroupError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "placeholder_taken"
    default_detail = "Someone already joined as this member."


def _is_member(user, group):
    return Member.objects.filter(group=group, user=user, deleted=False).exists()


def create_invite(user, group_id, member_id=None):
    """A new invite to `group_id` (an entity id), optionally for a placeholder."""
    group = Group.objects.filter(entity_id=group_id, deleted=False).first()
    if group is None or not _is_member(user, group):
        raise GroupNotFound()
    member = None
    if member_id is not None:
        member = Member.objects.filter(group=group, entity_id=member_id).first()
        if member is None or member.deleted or member.user_id is not None:
            raise NotAPlaceholder()
    return GroupInvite.objects.create(
        token=secrets.token_urlsafe(24),
        group=group,
        member=member,
        created_by=user,
        expires_at=timezone.now() + INVITE_TTL,
    )


def _open(user, token, for_update=False):
    """The invite, if `user` may still use it. Raises otherwise."""
    invites = GroupInvite.objects.select_related("group", "member", "created_by")
    if for_update:
        invites = invites.select_for_update(of=("self",))
    invite = invites.filter(token=token).first()
    if invite is None or invite.group.deleted:
        raise InviteNotFound()
    if invite.used_by_id is not None and invite.used_by_id != user.pk:
        raise InviteUsed()
    if invite.used_by_id is None and invite.expires_at <= timezone.now():
        raise InviteExpired()
    return invite


def preview(user, token):
    """What the app shows before joining."""
    invite = _open(user, token)
    return {
        "groupId": invite.group.entity_id,
        "groupName": invite.group.name,
        "currency": invite.group.currency,
        "memberName": invite.member.display_name if invite.member else None,
        "invitedBy": display_name(invite.created_by),
        "expiresAt": invite.expires_at,
    }


def join(user, token):
    """Joins the invite's group: claims its placeholder, or adds a member.
    Returns (group, member). Joining again with an invite this user already
    used returns the same answer, so a lost response is safe to retry."""
    with transaction.atomic():
        lock_ledger()
        invite = _open(user, token, for_update=True)
        if invite.used_by_id is not None:
            return invite.group, invite.member
        group = invite.group
        if _is_member(user, group):
            raise AlreadyMember()

        if invite.member is not None:
            member = Member.objects.select_for_update().get(pk=invite.member.pk)
            if member.deleted or member.user_id is not None:
                raise PlaceholderTaken()
            member.user = user
            member.updated_by = user
            member.save()
            _history(user, group, member, EntityHistory.Kind.CHANGED, "userId", None, str(user.pk))
        else:
            member = Member(
                entity_id=str(uuid.uuid4()),
                group=group,
                user=user,
                display_name=display_name(user),
                updated_by=user,
            )
            member.save()
            _history(user, group, member, EntityHistory.Kind.CREATED)

        invite.member = member
        invite.used_by = user
        invite.used_at = timezone.now()
        invite.save()
        joined(user, group, member)
        return group, member


def display_name(user):
    """The name other members see: the account's, or its email's first part."""
    return (user.display_name or user.email.split("@")[0])[:50]


def _history(user, group, member, kind, field="", old=None, new=None):
    EntityHistory.objects.create(
        entity="members",
        entity_id=member.entity_id,
        group=group,
        kind=kind,
        field=field,
        old_value=old,
        new_value=new,
        changed_by=user,
        version=member.version,
    )
