from django.urls import path

from .views import get_all_data

urlpatterns = [
    path("", get_all_data),
]
