from django.urls import path

from . import views

urlpatterns = [
    path("push", views.PushView.as_view(), name="sync-push"),
]
