<p align="center">
  <img src="https://raw.githubusercontent.com/jezsung/query/main/assets/logo.svg" alt="flutter_query logo" width="80">
</p>

<h1 align="center"><samp>Flutter Query</samp></h1>

<p align="center">
  <a href="https://github.com/jezsung/query/actions/workflows/ci.yaml"><img src="https://github.com/jezsung/query/actions/workflows/ci.yaml/badge.svg" alt="CI Status"></a>
  <a href="https://codecov.io/github/jezsung/query" ><img src="https://codecov.io/github/jezsung/query/graph/badge.svg?token=8ZS2VDHJ71&flag=flutter_query"/></a>
  <a href="https://github.com/jezsung/query/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-purple.svg" alt="License"></a>
  <a href="https://github.com/jezsung/query"><img src="https://img.shields.io/github/stars/jezsung/query?style=flat&logo=github&colorB=F6F8FA&label=Github%20Stars" alt="GitHub Stars"></a>
</p>

Powerful asynchronous state management for Flutter, inspired by
[TanStack Query](https://tanstack.com/query/latest). Simplifies data fetching, caching, and updates
with minimal boilerplate.

> **Coming from TanStack Query?** Check out the
> [differences](https://flutterquery.com/docs/coming-from-tanstack-query) to get started quickly.

## Why Flutter Query?

Working with server data is hard. You need caching, request deduplication, background refetching,
stale data handling, and more. Flutter Query handles all of this out of the box:

- **Automatic Caching:** Cache management with configurable stale times
- **Request Deduplication:** Multiple widgets share a single network request
- **Background Refetching:** Keep data fresh with automatic background updates
- **Stale-While-Revalidate:** Show cached data instantly while fetching updates
- **Optimistic Updates:** Responsive UI with rollback on failure
- **Infinite Queries:** Built-in pagination for infinite scrolling view
- **Automatic Retries:** Configurable retry logic with exponential backoff
- **Lifecycle Aware:** Automatic refetch on app resume

## Documentation

Visit **[flutterquery.com](https://flutterquery.com)** for comprehensive documentation:

- [Overview](https://flutterquery.com/docs/overview)
- [Quick Start](https://flutterquery.com/docs/quick-start)

## Versioning

This project strictly follows [Semantic Versioning](https://semver.org/). Given a version number
`MAJOR.MINOR.PATCH`:

- **MAJOR** version increments indicate breaking changes
- **MINOR** version increments add functionality in a backward-compatible manner
- **PATCH** version increments include backward-compatible bug fixes

Before version 1.0.0, MINOR version increments may include breaking changes.
