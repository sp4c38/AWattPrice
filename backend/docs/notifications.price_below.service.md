# **Price Below Notification Service**

This describes details about the price below notification service.

### **How to run and how it runs**

This service should be called in periodical time intervals. So it's no long-running service but rather a service or program which does certain things and then exists, waiting to be called again. For example you can use crontab to call it in certain periods. It is recommended to run it more often in the hours in which price data will likely update, which is 13 to 15 o'clock in the afternoon and less often in hours in which prices won't update.

<span style="color:red;">Note:</span> For backwards compatibility reasons the database of the legacy backend also gets read and processed if it is specified in the backend's config. Users only registered in the legacy backend will thus also receive price below notifications, just like before.

### **Process of sending price below notifications**

1. Get the current price data of all regions. This may be locally cached data or new remotely downloaded data.
2. Previous runs which sent notifications stored a certain identifier on the filesystem which can now be used to evaluate if the current price data we just got changed relative to the price data of the run back then. Check this for each region for which we could get price data in step 1.
   - Didn't change/update: Exit
   - Did change/update: Continue
3. Read and collect all necessary data from the current backend's database *as well as* from the old backend's database. Only select the users which are in one of the regions which apply to get updated.
4. Evaluate which users apply to receive a price below notification. This is based on factors like the set price below value. Note: This doesn't include the region because this was already checked in the previous steps.
5. Send the users their notifications.
6. Get the identifiers of the price datas which this run was based on of each region. Store these identifiers.
