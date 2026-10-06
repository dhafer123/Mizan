from rest_framework import serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from . import services


class _CreateInviteSerializer(serializers.Serializer):
    # A placeholder to claim; omit for an invite that adds a new member.
    memberId = serializers.CharField(source="member_id", max_length=64, required=False)


class CreateInviteView(APIView):
    def post(self, request, group_id):
        serializer = _CreateInviteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        invite = services.create_invite(request.user, group_id, serializer.validated_data.get("member_id"))
        return Response(
            {
                "token": invite.token,
                "groupId": group_id,
                "memberId": invite.member.entity_id if invite.member else None,
                "expiresAt": invite.expires_at,
            },
            status=status.HTTP_201_CREATED,
        )


class InviteView(APIView):
    def get(self, request, token):
        return Response(services.preview(request.user, token))


class JoinView(APIView):
    def post(self, request, token):
        group, member = services.join(request.user, token)
        return Response({"groupId": group.entity_id, "memberId": member.entity_id})
