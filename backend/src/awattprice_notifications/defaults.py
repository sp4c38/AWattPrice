"""Default values and models public for all awattprice notification services."""
from box import Box

PRICE_BELOW_SERVICE_NAME = "price_below"

APNS_ENCRYPTION_ALGORITHM = "ES256"
APNS_ENCRYPTION_KEY_FILE_NAME = "encryption_key.p8"
APNS_URL = Box()
APNS_URL.origin = {}
APNS_URL.origin.sandbox = "https://api.sandbox.push.apple.com:443"
APNS_URL.origin.production = "https://api.push.apple.com:443"
APNS_URL.path = "/3/device/{}" 
APNS_TIMEOUT = 15
APNS_ATTEMPTS = 3  # Number of maximal attempts to perform retrying.
APNS_STOP_DELAY = 30  # Delay after which to stop retrying,
