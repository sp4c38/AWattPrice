==================
AWattPrice Backend
==================

Fetch aWATTar data and provide it to the AWattPrice app.

Description
===========

The AWattPrice app needs to get the current power price data. This FastAPI backend provides this data to the
client. The backend gets this data by polling the public `aWATTar API <https://www.awattar.de/services/api>`_
It also caches the results to offload the aWATTar API.
