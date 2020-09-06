from django.http import HttpResponse, JsonResponse
from django.shortcuts import render

from .data import parse_data

def get_all_data(request):
    return JsonResponse(parse_data.main())
