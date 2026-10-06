from django.urls import path

from . import views

urlpatterns = [
    path("invites/<str:token>", views.InviteView.as_view(), name="group-invite"),
    path("invites/<str:token>/join", views.JoinView.as_view(), name="group-join"),
    path("<str:group_id>/invites", views.CreateInviteView.as_view(), name="group-invites"),
]
