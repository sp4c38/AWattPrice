# **General**
This documentation shall describe how AWattPrice handles certain situations etc. The specifications should *not* be understood as some description how to access the web app. The backend should *only* be accessed by the actual iOS app. It's a documentation *for backend developers* to understand certain concepts quicker.

### **Base structure of the src directory and the different packages**

```
src
├── awattprice
│
└── awattprice_notifications
    └── ...
```

- awattprice: Package with the FastAPI web application. This is the main package.
- awattprice_notifications: Package containing the different notification type services. These different notification type services are subpackages of this root package. For example the 'price_below' directory inside of this main directory is a subpackage of it describing the service to send price below notifications.

<span style="color:orange;">Dependency note:</span> There is no extra package for unified cross-package code. Code in one package also used by another package should be placed in the package where it fits in best. If it's hard to differentiate where to fit the code best try to place it in the `src/awattprice/` directory because this is the main package.


### **Data stored**
The AWattPrice backend needs to store data on the file system. This data includes cached energy data, notification data of the clients, logs and more. To store this data AWattPrice uses its own directories. The paths for these can be configured in the config file. They default to `~/awattprice/...`. You can specify to store certain categories of files in other places than others. For example the log directory path can be configured to be stored at another place than the data directory path.

<span style="color:red">Note:</span> The directories to store this data are *only* checked at startup of the web app. After the app was started it assumes that these directories exist. They *should not* be deleted while the app is running.
