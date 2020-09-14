from django.http import HttpResponse, JsonResponse
from django.shortcuts import render

from . import merge_data

def get_all_data(request):
    return JsonResponse(merge_data.main())
