from datetime import timedelta

from django.utils import timezone
from rest_framework import serializers

# Caps well above what a person logs, so a broken client can't skew the totals much.
MAX_PER_DAY = 500
MAX_DAYS = 31
OLDEST_DAY = 60


class FeedbackSerializer(serializers.Serializer):
    message = serializers.CharField(max_length=2000)
    contact = serializers.CharField(max_length=254, required=False, allow_blank=True, default="")
    appVersion = serializers.CharField(source="app_version", max_length=32)


class _UsageDaySerializer(serializers.Serializer):
    day = serializers.DateField()
    manual = serializers.IntegerField(min_value=0, max_value=MAX_PER_DAY)
    voice = serializers.IntegerField(min_value=0, max_value=MAX_PER_DAY)
    receipt = serializers.IntegerField(min_value=0, max_value=MAX_PER_DAY)

    def validate_day(self, value):
        today = timezone.now().date()
        # The phone's local day can be ahead of the server's UTC day.
        if value > today + timedelta(days=1) or value < today - timedelta(days=OLDEST_DAY):
            raise serializers.ValidationError("Out of range.", code="day_out_of_range")
        return value


class UsageReportSerializer(serializers.Serializer):
    installId = serializers.UUIDField(source="install_id")
    appVersion = serializers.CharField(source="app_version", max_length=32)
    days = _UsageDaySerializer(many=True, allow_empty=False, max_length=MAX_DAYS)

    def validate_days(self, value):
        if len({entry["day"] for entry in value}) != len(value):
            raise serializers.ValidationError("Each day once.", code="duplicate_day")
        return value
