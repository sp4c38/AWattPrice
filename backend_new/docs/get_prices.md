This documentation shall describe how AWattPrice handles certain situations. The specifications should *not* be understood as some description how to access the web app or whatsoever. The backend should *only* be accessed by the actual iOS app. It's a documentation *for backend developers* to later understand certain concepts quicker.

# **Get current aWATTar prices**

Following is a description of the way the back-end attempts to get the latest aWATTar price data.

#### Local and remote data
It is important that the aWATTar price API doesn't get overloaded. Thus price data needs to be cached locally. For this to work a function is needed, which evaluates if new prices should be downloaded. Previously this very thing was attempted by looking at the number of future price points. If this number was smaller than a given threshold (e.g. smaller than 12) prices would be updated from aWATTar. In the current version the back-end now checks the current hour to evaluate. For example, if its past the 13ths hour prices get updated. As soon as prices are updated they are cached locally. Following requests, then return the local cached data instead of getting the prices each time from aWATTar.

#### Process of getting current prices

1. Get last locally cached data.
2. Check if local data needs to be updated.
3. - No: Use locally cached data as price data. Continue at step 5.
   - Yes: Continue at step 4.
4. Get new price data. Therefor a refresh lock needs to be acquired which leads to one of the following paths:
   - Lock can be acquired immediately without waiting: Poll the newest price data from aWATTar, store it and then release the lock.
   - Lock can be acquired after waiting: If we needed to wait for the refresh lock to get acquired we know that a other request which updated the data when we were waiting to acquire the lock came before us. It was still downloading and processing the data because of which at the first read we still had the old data. We thus know that now the locally cached price data is up to date because it was just now updated by another request. For that release the lock, read it and use it as current price data.
   - Lock couldn't be acquired (timed out when acquiring lock): This is a situation which should not occur. The steps taken here are more an emergency handling. If we could previously read local data, then use this as the current price data. If we don't have any local data cached, then return a 500 error response.
5. Respond with the current price data.
