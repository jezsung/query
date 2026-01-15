<p align="center">
  <img src="https://raw.githubusercontent.com/jezsung/query/main/assets/logo.svg" alt="flutter_query logo" width="80">
</p>
<h1 align="center"><samp>Flutter Query</samp></h1>

<p align="center">
  <a href="https://github.com/jezsung/query/actions/workflows/ci.yaml"><img src="https://github.com/jezsung/query/actions/workflows/ci.yaml/badge.svg" alt="CI Status"></a>
  <a href="https://codecov.io/github/jezsung/query" ><img src="https://codecov.io/github/jezsung/query/graph/badge.svg?token=8ZS2VDHJ71&flag=flutter_query"/></a>
  <a href="https://github.com/jezsung/query/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-purple.svg" alt="MIT License"></a>
  <a href="https://github.com/jezsung/query"><img src="https://img.shields.io/github/stars/jezsung/query?style=flat&logo=github&colorB=F6F8FA&label=Github%20Stars" alt="GitHub Stars"></a>
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_query"><img src="https://img.shields.io/pub/v/flutter_query?label=Pub&color=027DFD" alt="Pub Version"></a>
  <a href="https://pub.dev/packages/flutter_query"><img src="https://img.shields.io/pub/points/flutter_query?label=Points&color=027DFD" alt="Pub Points"></a>
  <a href="https://pub.dev/packages/flutter_query"><img src="https://img.shields.io/pub/likes/flutter_query?label=Likes&color=027DFD" alt="Pub Likes"></a>
</p>

A Flutter package inspired by [TanStack Query](https://tanstack.com/query/latest) for powerful
asynchronous state management. Built with [Flutter Hooks](https://pub.dev/packages/flutter_hooks).

> **Coming from TanStack Query?** Check out the
> [differences](https://flutterquery.com/docs/coming-from-tanstack-query) to get started quickly.

## Why Flutter Query?

Working with server data is hard. You need caching, deduplication, background refetching, stale data
handling, and more. Flutter Query handles all of this out of the box:

- **Automatic caching** with intelligent invalidation
- **Request deduplication** so multiple widgets share a single network request
- **Background updates** to keep data fresh
- **Stale-while-revalidate** patterns for instant UI with fresh data
- **Optimistic updates** for responsive mutations
- **Retry logic** with exponential backoff

## Documentation

Visit [flutterquery.com](https://flutterquery.com) for the full documentation, tutorials, and
guides.

## Versioning

This project strictly follows [Semantic Versioning](https://semver.org/). Given a version number
`MAJOR.MINOR.PATCH`:

- **MAJOR** version increments indicate breaking changes
- **MINOR** version increments add functionality in a backward-compatible manner
- **PATCH** version increments include backward-compatible bug fixes

Before version 1.0.0, MINOR version increments may include breaking changes.

## Support

If you find Flutter Query useful, consider giving it a ⭐ to help others discover it!

[![Star History Chart](https://api.star-history.com/svg?repos=jezsung/query&type=Date)](https://star-history.com/#jezsung/query&Date)
