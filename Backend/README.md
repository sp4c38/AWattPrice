## Backend Code for the AWattPrice-App

Contains the code for the backend of the App which is responsible for downloading data from the aWATTar public API and converting it to a JSON output. This output is polled by the App to get up to date data.

### Why create another Single Point of Failure?
There are several reasons why its helpful to create a backend which downloads, converts and keeps the data ready for requests by the app:

* Cache data and don't poll API too often which may cause problems with the provider
* Faster for the App to poll only one data source instead of multiple (if the app supports data retrieval from multiple data sources in the future)
* Modify and customly prepare the data returned to the App
* Better privacy can be ensured because the data source(s) don't get to know the IP-Addresses,... from the client. The webserver from which the client downloads the current energy prices won't store any user data to protect the privacy of the user.
* Better error handling (e.g. returned data by api has different format -> fix error server-side and don't need to first publish a new app update which would take some time to get accepted)
