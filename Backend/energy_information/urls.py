from django.urls import path

from .awattar.get_data import get_data

urlpatterns = [
    path("", get_data)
]
