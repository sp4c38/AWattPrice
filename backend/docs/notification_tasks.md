This documentation shall describe how AWattPrice handles certain situations. The specifications should *not* be understood as some description how to access the web app or whatsoever. The backend should *only* be accessed by the actual iOS app. It's a documentation *for backend developers* to later understand certain concepts quicker.

# **Notification Tasks**

Notification tasks are tasks to update the notification configuration of a token. A request to run notification tasks must always include 1) the token and 2) the tasks.

### Tasks available

- Add token to the database.
- Subscribe/desubscribe to notification.

### Rules when sending tasks

- Add token tasks:
  - May only exist once in one request.
  - If included must always be the first item in the task list.
- Subscribe/desubscribe task:
  - May only either subscribe or desubscribe to one certain notification type
