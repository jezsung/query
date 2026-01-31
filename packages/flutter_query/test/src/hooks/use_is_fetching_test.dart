import 'dart:async';

import 'package:flutter_hooks_test/flutter_hooks_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';
import 'package:flutter_query/src/hooks/hooks.dart';
import '../../utils.dart';

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient();
  });

  tearDown(() {
    client.clear();
  });

  testWidgets(
      'SHOULD return 0 '
      'WHEN no queries are fetching', withCleanup((tester) async {
    final hook = await buildHook(
      () => useIsFetching(client: client),
    );

    expect(hook.current, 0);
  }));

  testWidgets(
      'SHOULD return 1 '
      'WHEN one query is fetching', withCleanup((tester) async {
    final hook = await buildHook(() {
      useQuery(
        const ['key'],
        (context) => Completer().future,
        client: client,
      );
      return useIsFetching(client: client);
    });

    expect(hook.current, 1);
  }));

  testWidgets(
      'SHOULD return correct count '
      'WHEN multiple queries are fetching', withCleanup((tester) async {
    final hook = await buildHook(() {
      useQuery(
        const ['first'],
        (context) async {
          await Future.delayed(const Duration(seconds: 3));
          return 'data';
        },
        client: client,
      );
      useQuery(
        const ['second'],
        (context) async {
          await Future.delayed(const Duration(seconds: 2));
          return 'data';
        },
        client: client,
      );
      return useIsFetching(client: client);
    });

    expect(hook.current, 2);

    client.fetchQuery(
      const ['third'],
      (context) async {
        await Future.delayed(const Duration(seconds: 1));
        return 'data';
      },
    ).ignore();
    await tester.pump();
    expect(hook.current, 3);

    // 'third' query completes
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current, 2);
    // 'second' query completes
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current, 1);
    // 'first' query completes
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current, 0);
  }));

  testWidgets(
      'SHOULD NOT count queries that are not fetching'
      '', withCleanup((tester) async {
    final hook = await buildHook(() {
      useQuery(
        const ['key'],
        (context) => Completer().future,
        enabled: false,
        client: client,
      );
      return useIsFetching(client: client);
    });

    expect(hook.current, 0);

    await tester.pump(const Duration(hours: 365));

    expect(hook.current, 0);
  }));

  testWidgets(
      'SHOULD return new count '
      'WHEN queryKey changes', withCleanup((tester) async {
    final hook = await buildHookWithProps(
      (List<Object?> queryKey) {
        useQuery(
          const ['users', 1],
          (context) async {
            await Future.delayed(const Duration(seconds: 2));
            return 'data';
          },
          client: client,
        );
        useQuery(
          const ['users', 2],
          (context) async {
            await Future.delayed(const Duration(seconds: 2));
            return 'data';
          },
          client: client,
        );
        useQuery(
          const ['posts', 1],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          client: client,
        );
        return useIsFetching(queryKey: queryKey, client: client);
      },
      initialProps: const ['users'],
    );
    expect(hook.current, 2);

    await hook.rebuildWithProps(const ['posts']);
    expect(hook.current, 1);

    // 'posts' query completes
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current, 0);

    // 'users' queries complete, should not affect count
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current, 0);
  }));

  testWidgets(
      'SHOULD return new count '
      'WHEN exact changes', withCleanup((tester) async {
    final hook = await buildHookWithProps(
      (bool exact) {
        useQuery(
          const ['users'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          client: client,
        );
        useQuery(
          const ['users', 1],
          (context) async {
            await Future.delayed(const Duration(seconds: 2));
            return 'data';
          },
          client: client,
        );
        useQuery(
          const ['users', 2],
          (context) async {
            await Future.delayed(const Duration(seconds: 2));
            return 'data';
          },
          client: client,
        );
        return useIsFetching(
          queryKey: const ['users'],
          exact: exact,
          client: client,
        );
      },
      initialProps: false,
    );
    // exact: false matches all 3 queries
    expect(hook.current, 3);

    await hook.rebuildWithProps(true);
    // exact: true matches only ['users']
    expect(hook.current, 1);

    // ['users'] query completes
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current, 0);

    // Other queries complete, should not affect count
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current, 0);
  }));

  testWidgets(
      'SHOULD return new count '
      'WHEN predicate changes', withCleanup((tester) async {
    final hook = await buildHookWithProps(
      (bool Function(List<Object?>, QueryState) predicate) {
        useQuery(
          const ['users', 1],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          client: client,
        );
        useQuery(
          const ['users', 2],
          (context) async {
            await Future.delayed(const Duration(seconds: 2));
            return 'data';
          },
          client: client,
        );
        useQuery(
          const ['users', 3],
          (context) async {
            await Future.delayed(const Duration(seconds: 2));
            return 'data';
          },
          client: client,
        );
        return useIsFetching(predicate: predicate, client: client);
      },
      initialProps: (key, state) => key.length > 1 && key[1] == 1,
    );
    // Predicate matches only ['users', 1]
    expect(hook.current, 1);

    await hook.rebuildWithProps((key, state) => key.length > 1 && key[1] != 1);
    // New predicate matches ['users', 2] and ['users', 3]
    expect(hook.current, 2);

    // ['users', 1] query completes, should not affect count
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current, 2);

    // ['users', 2] and ['users', 3] complete
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current, 0);
  }));

  testWidgets(
      'SHOULD filter by key prefix '
      'WHEN exact == false', withCleanup((tester) async {
    final hook = await buildHook(() {
      useQuery(
        const ['users'],
        (context) => Completer().future,
        client: client,
      );
      useQuery(
        const ['users', 1],
        (context) => Completer().future,
        client: client,
      );
      useQuery(
        const ['users', 2],
        (context) => Completer().future,
        client: client,
      );
      useQuery(
        const ['posts', 1],
        (context) => Completer().future,
        client: client,
      );
      return (
        users: useIsFetching(
          queryKey: const ['users'],
          exact: false,
          client: client,
        ),
        posts: useIsFetching(
          queryKey: const ['posts'],
          exact: false,
          client: client,
        ),
        comments: useIsFetching(
          queryKey: const ['comments'],
          exact: false,
          client: client,
        ),
      );
    });

    expect(hook.current.users, 3);
    expect(hook.current.posts, 1);
    expect(hook.current.comments, 0);
  }));

  testWidgets(
      'SHOULD filter by exact key '
      'WHEN exact == true', withCleanup((tester) async {
    final hook = await buildHook(() {
      useQuery(
        const ['users'],
        (context) => Completer().future,
        client: client,
      );
      useQuery(
        const ['users', 1],
        (context) => Completer().future,
        client: client,
      );
      useQuery(
        const ['users', 2],
        (context) => Completer().future,
        client: client,
      );
      return useIsFetching(
        queryKey: const ['users'],
        exact: true,
        client: client,
      );
    });

    expect(hook.current, 1);
  }));

  testWidgets(
      'SHOULD filter by predicate'
      '', withCleanup((tester) async {
    final hook = await buildHook(() {
      useQuery(
        const ['users'],
        (context) => Completer().future,
        client: client,
      );
      useQuery(
        const ['users', 1],
        (context) => Completer().future,
        client: client,
      );
      useQuery(
        const ['users', 2],
        (context) => Completer().future,
        client: client,
      );
      return useIsFetching(
        predicate: (key, state) => key.length > 1 && key[1] == 1,
        client: client,
      );
    });

    expect(hook.current, 1);
  }));

  testWidgets(
      'SHOULD filter by key and predicate'
      '', withCleanup((tester) async {
    final hook = await buildHook(() {
      useQuery(
        const ['users', 1],
        (context) => Completer().future,
        client: client,
      );
      useQuery(
        const ['users', 2],
        (context) => Completer().future,
        client: client,
      );
      useQuery(
        const ['posts', 1],
        (context) => Completer().future,
        client: client,
      );
      return useIsFetching(
        queryKey: const ['users'],
        predicate: (key, state) => key.length > 1 && key[1] == 1,
        client: client,
      );
    });

    expect(hook.current, 1);
  }));
}
