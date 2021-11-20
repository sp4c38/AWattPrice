# Note!

<span style="color:red">
The backend you find in this directory is the old backend.  This backend was
rewrote to fix design flaws and other issues and is currently still
operated server-side for backward compatibility. It is therefor still kept in this
repository at this place.
</span>

---

AWattPrice Backend
==================

Fetch data from awattar and provide it to the App.


Description
===========

The Awattprice app polls for power price data. This little `FastAPI <https://fastapi.tiangolo.com>`_
app is the backend to provide the data to the clients. To get the latest data it pulls the data
from from the `Awattar API <https://www.awattar.de/services/api>`_ and caches it.
