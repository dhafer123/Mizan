from rest_framework.response import Response
from rest_framework.views import APIView

from . import push
from .serializers import PushSerializer


class PushView(APIView):
    def post(self, request):
        serializer = PushSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        return Response({"results": push.push(request.user, data["device_id"], data["ops"])})
