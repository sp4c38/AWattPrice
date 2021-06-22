# **Notification Tasks**

Notification tasks are tasks to update the notification configuration of a token. A request to run notification tasks must always include 1) the token and 2) the task descriptions.

### Tasks available

- Add token to the database.
- Subscribe/desubscribe to notification.
- Update task:
  - Update general configuration (e.g. selected region, vat selection, ...)
  - Update specific notification configuration (e.g. update price below value of the price below notification).

### Rules when sending tasks

- Add token tasks:
  - May only exist once in one request.
  - If included must always be the first item in the task list.
- Subscribe/desubscribe task:
  - Only either subscribe or desubscribe to one certain notification type.
- Update task:
  - Only include one update task for each subject. Subjects are the different available targets which are updatable, for example general configuration is a subject and the price below notification configuration is a subject which is updatable.
