from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from . import services
from .serializers import LogInSerializer, LogOutSerializer, RefreshSerializer, SignUpSerializer, UserSerializer


def _session(user, tokens):
    return {"user": UserSerializer(user).data, **tokens}


class _PublicView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]


class SignUpView(_PublicView):
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth"

    def post(self, request):
        serializer = SignUpSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user, tokens = services.sign_up(**serializer.validated_data)
        return Response(_session(user, tokens), status=status.HTTP_201_CREATED)


class LogInView(_PublicView):
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth"

    def post(self, request):
        serializer = LogInSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user, tokens = services.log_in(request, **serializer.validated_data)
        return Response(_session(user, tokens))


class RefreshView(_PublicView):
    def post(self, request):
        serializer = RefreshSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(services.refresh_tokens(serializer.validated_data["refresh"]))


class LogOutView(_PublicView):
    def post(self, request):
        serializer = LogOutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        services.log_out(
            raw_refresh=serializer.validated_data["refresh"],
            device_id=serializer.validated_data.get("device_id"),
        )
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(APIView):
    def get(self, request):
        return Response(UserSerializer(request.user).data)
