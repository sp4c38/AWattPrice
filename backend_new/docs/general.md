# **General**
Short information to some general important things to note about the AWattPrice backend.

## **Data stored**
The AWattPrice backend needs to store data on the file system. This data includes cached energy data, notification data of the clients, logs and more. To store this data AWattPrice creates directories. The paths for these can be configured in the config file. They default to `~/awattprice/...`.

<span style="color:red">! Note !</span> The directories to store this data are *only* checked at startup of the web app. After the app was started it assumes that these directories exist. They *should not* be deleted while the app is running.
