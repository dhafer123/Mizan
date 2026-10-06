from django.db import DatabaseError, connection
from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response


@api_view(["GET"])
@authentication_classes([])
@permission_classes([AllowAny])
def health(request):
    """Liveness + database check, for Docker healthchecks and the app's "server reachable" probe."""
    try:
        connection.ensure_connection()
    except DatabaseError:
        return Response({"status": "error", "database": "unreachable"}, status=503)
    return Response({"status": "ok"})
