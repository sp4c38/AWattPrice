# **General**
This documentation shall describe how AWattPrice handles certain situations etc. The specifications should *not* be understood as some description how to access the web app or whatsoever. The backend should *only* be accessed by the actual iOS app. It's a documentation *for backend developers* to understand certain concepts quicker.

## **Data stored**
The AWattPrice backend needs to store data on the file system. This data includes cached energy data, notification data of the clients, logs and more. To store this data AWattPrice uses its own directories. The paths for these can be configured in the config file. They default to `~/awattprice/...`. You can specify to store certain categories of files in other places than others. For example the log directory path can be configured to be stored at another place than the data directory path.

<span style="color:red">! Note !</span> The directories to store this data are *only* checked at startup of the web app. After the app was started it assumes that these directories exist. They *should not* be deleted while the app is running.
