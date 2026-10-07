from rest_framework import serializers

from .models import Device, User


class DeviceSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    platform = serializers.ChoiceField(choices=Device.Platform.choices)
    name = serializers.CharField(max_length=100, required=False, allow_blank=True, default="")


class SignUpSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=254)
    password = serializers.CharField(max_length=128, trim_whitespace=False, write_only=True)
    displayName = serializers.CharField(
        source="display_name", max_length=50, required=False, allow_blank=True, default=""
    )
    device = DeviceSerializer(required=False)


class LogInSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=254)
    password = serializers.CharField(max_length=128, trim_whitespace=False, write_only=True)
    device = DeviceSerializer(required=False)


class RefreshSerializer(serializers.Serializer):
    refresh = serializers.CharField()


class LogOutSerializer(serializers.Serializer):
    refresh = serializers.CharField()
    deviceId = serializers.UUIDField(source="device_id", required=False)


class PushTokenSerializer(serializers.Serializer):
    # Empty stops pushes to this device (e.g. notifications turned off).
    token = serializers.CharField(max_length=4096, allow_blank=True)


class UserSerializer(serializers.ModelSerializer):
    # A string, so clients treat ids as opaque.
    id = serializers.CharField(read_only=True)
    displayName = serializers.CharField(source="display_name", read_only=True)

    class Meta:
        model = User
        fields = ["id", "email", "displayName"]
