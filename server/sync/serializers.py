from rest_framework import serializers

from .pull import DEFAULT_LIMIT, MAX_LIMIT
from .push import MAX_OPS


class PushSerializer(serializers.Serializer):
    """The envelope only. Each op is checked by the push service, so one bad
    op is rejected on its own instead of blocking the whole queue."""

    deviceId = serializers.UUIDField(source="device_id")
    ops = serializers.ListField(child=serializers.JSONField(), max_length=MAX_OPS)


class PullQuerySerializer(serializers.Serializer):
    since = serializers.IntegerField(min_value=0, default=0)
    limit = serializers.IntegerField(min_value=1, max_value=MAX_LIMIT, default=DEFAULT_LIMIT)
