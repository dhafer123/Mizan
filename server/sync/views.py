from rest_framework.response import Response
from rest_framework.views import APIView

from . import pull, push
from .serializers import PullQuerySerializer, PushSerializer


class PushView(APIView):
    def post(self, request):
        serializer = PushSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        return Response({"results": push.push(request.user, data["device_id"], data["ops"])})


class PullView(APIView):
    def get(self, request):
        query = PullQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        return Response(pull.pull(request.user, query.validated_data["since"], query.validated_data["limit"]))
