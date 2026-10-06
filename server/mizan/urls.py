from django.urls import include, path

from . import views

urlpatterns = [
    path("health", views.health, name="health"),
    path("auth/", include("accounts.urls")),
    path("sync/", include("sync.urls")),
    path("groups/", include("groups.urls")),
]
