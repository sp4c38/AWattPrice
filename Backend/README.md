## Backend Code for the AwattarApp

Contains the code for the backend of the App which is responsible for downloading data from multiple sources and convert it to a JSON output. This output is polled by the App to get up to date data.

### Why create another Single Point of Failure?
There are several reasons why its helpful to create a backend which downloads and converts the data:

* Cache data and don't poll APIs and websites too often which may cause problems with the providers
* Faster for the App to poll only one data source instead of multiple
* Modify and customly prepare the data returned to the App
* Track and monitor the amount of requests by clients
* Better error handling (e.g. provider now requires token -> can fix directly on server and don't need to update the app which would take some time to fix)