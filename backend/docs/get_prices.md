# **Get current aWATTar prices**

Following is a description of the way the back-end attempts to get the latest aWATTar price data.

#### Local and remote data
It is important that the aWATTar price API doesn't get overloaded. Thus price data needs to be cached locally. For this to work a function is needed, which evaluates if new prices should be downloaded. Previously this very thing was attempted by looking at the number of future price points. If this number was smaller than a given threshold (e.g. smaller than 12) prices would be updated from aWATTar. In the current version the back-end now checks the current hour to evaluate. For example, if its past the 13ths hour prices get updated. As soon as prices are updated they are cached locally. Following requests, then return the local cached data instead of getting the prices each time from aWATTar.

#### Process of getting current prices

1. Concurrently get last locally cached price data and the last update timestamp.
2. Check if local data needs to be updated.
    - Check if it's past a certain hour.
    - Check if we don't have prices until the next day midnight.
    - Check if we already can update again relative to the last update timestamp.
        - No -> Continue at step X
        - Yes -> Continue at next step.
3. Acquire a refresh lock. Using this lock technique to every time *only one* call will be able to update the price data. After acquiring one of the following ways is followed:
   1. Lock could be acquired immediately without waiting. Continue at step 4 - the actual download process.
   2. Lock could be acquired but needed to wait. We can infert that another call already polled new price data but didn't write it yet while we were reading. So read local data again and use it as the current price data (continue at step X).
   3. Lock couldn't be acquired at all (timed out). Should never happen but is possible, for example if the aWATTar servers aren't responding in another call. If stored data exists this is the current price data (continue at step X), if it's missing throw a http 500 error.
4. There is one big issue: Assume that after the data was loaded from cache it changed - so a other call updated it. Also assume that the 2nd way in the 3rd step didn't happen because of a certain timing. We would now still update the data altough we actually already have the updated version. To completely prevent this case we would need to read again. But as this is very cost-intensive and this case is very unlikely it will not be prevented. The web app will check the update timestamp which doesn't make it a necessarity that a actual update will occur.
5. Read and check last update timestamp again. This is done again because due to having the lock acquired this time we can rely that the timestamp read is correct. This previously wasn't the case because it could have come to certain race conditions.
6. Download the data.
7. Check if new price points were added compared to the locally stored data.
   - Yes -> Store new data and use it as current price data.
   - No -> Don't store new data and use the stored data as current price data.
8. Return a transformed version of whatever the current price data was found to be above.

The returned data includes following:

- Price data
