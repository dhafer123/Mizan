from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from . import services
from .serializers import FeedbackSerializer, UsageReportSerializer


class _AnonymousView(APIView):
    # No authentication at all: a signed-in app's token is ignored, so nothing
    # sent here can be tied to an account (ADR 0019).
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "beta"


class FeedbackView(_AnonymousView):
    def post(self, request):
        serializer = FeedbackSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        services.send_feedback(**serializer.validated_data)
        return Response(status=status.HTTP_201_CREATED)


class UsageView(_AnonymousView):
    def post(self, request):
        serializer = UsageReportSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        services.record_usage(**serializer.validated_data)
        return Response(status=status.HTTP_204_NO_CONTENT)
