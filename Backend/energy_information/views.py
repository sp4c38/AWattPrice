from django.http import HttpResponse, JsonResponse
from django.shortcuts import render

from .awattar import parse_data as awattar_parse_data

def get_all_data(request):
    return JsonResponse(awattar_parse_data.main())
