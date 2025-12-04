### What is Flutter Query?

Powerful asynchronous state management, server-state utilities and data fetching.

Flutter Query helps you fetch, cache, update, and wrangle all forms of asynchronous data in your Flutter applications without requiring a separate "global state" store. It is inspired by the ideas behind TanStack Query (commonly used in TS/JS frameworks such as React, Vue, Solid, Svelte & Angular), bringing the same developer ergonomics and server-state utilities to Flutter.

With Flutter Query you'll get a declarative API and widgets that make it simpler to:

- Fetch and cache async data from remote APIs
- Track loading, success, and error states with minimal boilerplate
- Read cached query data from anywhere in the widget tree
- Configure staleness and background re-fetching policies
- Reduce redundant network requests via request de-duplication
- Retry and backoff strategies for resilient fetching
- Cancel in-flight requests and roll back optimistic updates
- Perform mutations with automatic cache invalidation and update hooks
- Support pagination and infinite scrolling / cursor-based fetching

These features let you focus on your UI and business logic instead of plumbing for network state and cache synchronization.

### Motivation

TanStack Query set a new standard for server-state management in the JavaScript/TypeScript ecosystem by solving a broad range of async-data problems (caching, background refetching, invalidation, optimistic updates, pagination) in a way that avoids coarse global state and lots of boilerplate.

Flutter lacked a widely-adopted, TanStack Query–style solution for server-state. Flutter Query aims to fill that gap: we follow the same proven patterns for managing server state, while providing widgets and hooks that feel natural in Flutter.

In short: if you want the ergonomics of TanStack Query (fetch-cache-update patterns, automatic synchronization, and low-boilerplate server state) — for Flutter — Flutter Query provides a familiar, powerful toolkit.
