from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models


def normalize_email(email):
    """Emails are case-insensitive here: stored trimmed and lowercased."""
    return email.strip().lower()


class UserManager(BaseUserManager):
    use_in_migrations = True

    def create_user(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        return self._create_user(email, password, **extra_fields)

    def _create_user(self, email, password, **extra_fields):
        if not email:
            raise ValueError("An email is required.")
        user = self.model(email=normalize_email(email), **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user


class User(AbstractUser):
    """A Mizan account. Signs in with email + password."""

    username = None
    first_name = None
    last_name = None
    email = models.EmailField("email address", unique=True)
    # Shown to group members (task 4.1). Optional; the app falls back to the email.
    display_name = models.CharField(max_length=50, blank=True)

    USERNAME_FIELD = "email"
    EMAIL_FIELD = "email"
    REQUIRED_FIELDS = []

    objects = UserManager()

    def __str__(self):
        return self.email


class Device(models.Model):
    """A phone signed in to an account, with its FCM push token once the app
    has sent one (`PUT /auth/devices/<id>/push-token`)."""

    class Platform(models.TextChoices):
        ANDROID = "android", "Android"
        IOS = "ios", "iOS"

    # Generated on the phone once per install, so it survives sign-out and sign-in.
    id = models.UUIDField(primary_key=True)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="devices")
    platform = models.CharField(max_length=16, choices=Platform.choices)
    name = models.CharField(max_length=100, blank=True)
    fcm_token = models.CharField(max_length=4096, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_seen_at = models.DateTimeField()

    def __str__(self):
        return f"{self.platform} device of {self.user_id}"
