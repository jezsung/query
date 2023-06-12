### What is Flutter Query?

Flutter Query provides declarative ways of fetching data from a server and displaying the data. With Flutter Query, you can easily:

- Fetch data from a server
- Handle the loading state while fetching
- Handle the error state when the fetching failed
- Cache the fetched data
- Access the cached data from anywhere in the widget tree
- Set when the data becomes stale and have to be refetched
- Reduce redundant API calls
- Cancel the ongoing fetch and revert the state
- Update UI instantly as the fetching succeeds

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
