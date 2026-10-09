from django.urls import path

from . import views

urlpatterns = [
    path("feedback", views.FeedbackView.as_view(), name="beta-feedback"),
    path("usage", views.UsageView.as_view(), name="beta-usage"),
]
