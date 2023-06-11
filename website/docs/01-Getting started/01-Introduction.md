### What is Flutter Query?

Flutter Query simplifies state management that involves asynchronous operations, such as API requests. Flutter Query provides comprehensive supports for data fetching, updating, caching, and sychronization.

### Motivation

State management is a big topic in Flutter and there are various state management packages and each has its own unique way of managing states.

There are two types of states. One is your app state and the other one is your server state. App state exists in your app and it does not depend on external resources. However, server state exists in remote location and your app needs to fetch the state by making API requests.

Managing server states come with a few challenges:

- Loading
- Error handling
- Caching
- Canceling redundant requests
- Knowing if data is up-to-date or not
- Updaing out-of-date data immediately
- Reflecting updated data to all related widgets as quickly as possible

Any kind of modern apps would face this chanllenges and even with help of current state management packages, it is not easy to solve all the above problems.

Flutter Query solves the above problems elegantly by providing a set of widgets.
