# -*- coding: utf-8 -*-

"""

AWattPrice types

"""
__author__ = "Frank Becker <fb@alien8.de>"
__copyright__ = "Frank Becker"
__license__ = "mit"


from typing import Dict

from pydantic import BaseModel


class APNSToken(BaseModel):
    token: str
    region_identifier: int
    vat_selection: int
    config: Dict
