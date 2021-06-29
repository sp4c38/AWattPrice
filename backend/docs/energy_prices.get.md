# **Get current aWATTar prices**

Following is a description of the way the backend attempts to get the latest aWATTar price data.

#### Local and remote data
It is important that the aWATTar price API doesn't get overloaded. Thus price data needs to be cached locally. For this to work a function is needed, which evaluates if new prices should be downloaded. Previously this very thing was attempted by looking at the number of future price points. If this number was smaller than a given threshold (e.g. smaller than 12) prices would be updated from aWATTar. In the current version the backend now checks the current hour to evaluate. For example, if its past the 13ths hour prices get updated. As soon as prices are updated they are cached locally. Following requests, then return the local cached data instead of getting the prices each time from aWATTar. If its past the 13ths hour and prices were already updated, the backend recognizes this by checking if there are prices until the following day midnight.

#### Process of getting current prices

1. Concurrently get last locally cached price data and the last update timestamp.
2. Check if local data needs to be updated:
    - Check if it's past a certain hour.
    - Check if we have prices until the next day midnight.
    - Check if we already can update again relative to the last update timestamp.
    - No -> Use local cached data as price data and continue at step 6.
    - Yes -> Continue at the next step.
3. Acquire a refresh lock. Using this lock technique at every time *only one* call will be able to update the price data. After acquiring one of the following paths is followed:
   1. Lock could be acquired immediately without waiting. Continue at step 4 - the actual download process.
   2. Lock could be acquired but needed to wait. We can infert that another call already polled new price data but didn't write it yet while we were reading. So read local data again and use it as the current price data (continue at step 6).
   3. Lock couldn't be acquired at all (timed out). Should never happen but is possible, for example if the aWATTar servers aren't responding in another call. If stored data exists this is the current price data (continue at step 6), if it's missing throw a http 500 error.
4. Download the data.
5. Check if new price points were added compared to the locally stored data.
   - Yes -> Store new data and use it as current price data.
   - No -> Don't store new data and use the stored data as current price data.
6. Return a transformed version of whatever the current price data was found to be in the above steps.

#### **<span style="color:orange;">Concurrency warning</span>**
The backend functions in a concurrent way. The intention of this is to speed up the request-response flow by managing multiple requests asynchronously. A common issue in such flows are race conditions. When finding the current prices certain race conditions can occur. They are very rare because they require certain timings, but are not impossible. There are definitely ways to fix such race conditions but they come at a high cost because certain files would need to be read multiple times during the flow. *The worst which can happen is that the backend polls price data twice from the aWATTar API* if two requests come in a certain very small timing right after each other. As fixing the race conditions comes at a way higher cost for the response time of each request-response flow during the update hours, the occurrence possibilities of such race conditions were minimised, but are still possible to occur. Even if they occur this is acceptable.
