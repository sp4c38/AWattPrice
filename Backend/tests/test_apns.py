# -*- coding: utf-8 -*-

import pytest
from awattprice.apns import validate_token

__author__ = "Frank Becker"
__copyright__ = "Frank Becker"
__license__ = "mit"



def test_validate_token():
    data = bytes('{"apnsDeviceToken": "ALovelyApnsToken", "regionIdentifier": 0, "vatSelection": 1, '
                 '"notificationConfig": {"priceBelowValueNotification": '
                 '{"active": true, "belowValue": 20}}}'.encode())
    assert validate_token(data) == {
        'token': 'ALovelyApnsToken',
        'region_identifier': 0,
        'vat_selection': 1,
        'config': {
            'price_below_value_notification': {
                'active': True,
                'below_value': 20.0
            }
        }
    }
    # apnsDeviceTokens is the wrong key
    data = bytes('{"apnsDeviceTokens": "ALovelyApnsToken", "regionIdentifier": 0, "vatSelection": 1, '
                 '"notificationConfig": {"priceBelowValueNotification": '
                 '{"active": true, "belowValue": 20}}}'.encode())
    assert validate_token(data) is None
    # active is the wrong type
    data = bytes('{"apnsDeviceTokens": "ALovelyApnsToken", "regionIdentifier": 0, "vatSelection": 1, '
                 '"notificationConfig": {"priceBelowValueNotification": '
                 '{"active": 0, "belowValue": 20}}}'.encode())
    assert validate_token(data) is None
