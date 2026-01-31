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
      'WHEN no mutations are pending', withCleanup((tester) async {
    final hook = await buildHook(
      () => useIsMutating(client: client),
    );

    expect(hook.current, 0);
  }));

  testWidgets(
      'SHOULD return 1 '
      'WHEN one mutation is pending', withCleanup((tester) async {
    final hook = await buildHook(() {
      final mutation = useMutation<String, dynamic, String, dynamic>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        client: client,
      );
      return (
        mutate: mutation.mutate,
        count: useIsMutating(client: client),
      );
    });

    expect(hook.current.count, 0);

    await act(() => hook.current.mutate('test'));

    expect(hook.current.count, 1);
  }));

  testWidgets(
      'SHOULD return correct count '
      'WHEN multiple mutations are pending', withCleanup((tester) async {
    final hook = await buildHook(() {
      final mutation1 = useMutation<String, dynamic, String, dynamic>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 2));
          return 'data-1';
        },
        client: client,
      );
      final mutation2 = useMutation<String, dynamic, String, dynamic>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-2';
        },
        client: client,
      );
      return (
        mutate1: mutation1.mutate,
        mutate2: mutation2.mutate,
        count: useIsMutating(client: client),
      );
    });

    expect(hook.current.count, 0);

    await act(() {
      hook.current.mutate1('test-1');
      hook.current.mutate2('test-2');
    });

    expect(hook.current.count, 2);

    // Second mutation completes after 1 second
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current.count, 1);
    // First mutation completes after another 1 second
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current.count, 0);
  }));

  testWidgets(
      'SHOULD return new count '
      'WHEN mutationKey changes', withCleanup((tester) async {
    final hook = await buildHookWithProps(
      (List<Object?> mutationKey) {
        final mutation1 = useMutation<String, dynamic, String, dynamic>(
          (variables, context) async {
            await Future.delayed(const Duration(seconds: 2));
            return 'data';
          },
          mutationKey: const ['users', 1],
          client: client,
        );
        final mutation2 = useMutation<String, dynamic, String, dynamic>(
          (variables, context) async {
            await Future.delayed(const Duration(seconds: 2));
            return 'data';
          },
          mutationKey: const ['users', 2],
          client: client,
        );
        final mutation3 = useMutation<String, dynamic, String, dynamic>(
          (variables, context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          mutationKey: const ['posts', 1],
          client: client,
        );
        return (
          mutate1: mutation1.mutate,
          mutate2: mutation2.mutate,
          mutate3: mutation3.mutate,
          count: useIsMutating(mutationKey: mutationKey, client: client),
        );
      },
      initialProps: const ['users'],
    );

    await act(() {
      hook.current.mutate1('test1');
      hook.current.mutate2('test2');
      hook.current.mutate3('test3');
    });
    expect(hook.current.count, 2);

    await hook.rebuildWithProps(const ['posts']);
    expect(hook.current.count, 1);

    // 'posts' mutation completes
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current.count, 0);
    // 'users' mutations complete, should not affect count
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current.count, 0);
  }));

  testWidgets(
      'SHOULD return new count '
      'WHEN exact changes', withCleanup((tester) async {
    final hook = await buildHookWithProps(
      (bool exact) {
        final mutation1 = useMutation<String, dynamic, String, dynamic>(
          (variables, context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          mutationKey: const ['users'],
          client: client,
        );
        final mutation2 = useMutation<String, dynamic, String, dynamic>(
          (variables, context) async {
            await Future.delayed(const Duration(seconds: 2));
            return 'data';
          },
          mutationKey: const ['users', 1],
          client: client,
        );
        final mutation3 = useMutation<String, dynamic, String, dynamic>(
          (variables, context) async {
            await Future.delayed(const Duration(seconds: 2));
            return 'data';
          },
          mutationKey: const ['users', 2],
          client: client,
        );
        return (
          mutate1: mutation1.mutate,
          mutate2: mutation2.mutate,
          mutate3: mutation3.mutate,
          count: useIsMutating(
            mutationKey: const ['users'],
            exact: exact,
            client: client,
          ),
        );
      },
      initialProps: false,
    );

    await act(() {
      hook.current.mutate1('test1');
      hook.current.mutate2('test2');
      hook.current.mutate3('test3');
    });
    expect(hook.current.count, 3);

    await hook.rebuildWithProps(true);
    expect(hook.current.count, 1);

    // ['users'] mutation completes
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current.count, 0);
    // Other mutations complete, should not affect count
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current.count, 0);
  }));

  testWidgets(
      'SHOULD return new count '
      'WHEN predicate changes', withCleanup((tester) async {
    final hook = await buildHookWithProps(
      (bool Function(List<Object?>?, MutationState) predicate) {
        final mutation1 = useMutation<String, dynamic, String, dynamic>(
          (variables, context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          mutationKey: const ['users', 1],
          client: client,
        );
        final mutation2 = useMutation<String, dynamic, String, dynamic>(
          (variables, context) async {
            await Future.delayed(const Duration(seconds: 2));
            return 'data';
          },
          mutationKey: const ['users', 2],
          client: client,
        );
        final mutation3 = useMutation<String, dynamic, String, dynamic>(
          (variables, context) async {
            await Future.delayed(const Duration(seconds: 2));
            return 'data';
          },
          mutationKey: const ['users', 3],
          client: client,
        );
        return (
          mutate1: mutation1.mutate,
          mutate2: mutation2.mutate,
          mutate3: mutation3.mutate,
          count: useIsMutating(predicate: predicate, client: client),
        );
      },
      initialProps: (key, state) =>
          key != null && key.length > 1 && key[1] == 1,
    );

    await act(() {
      hook.current.mutate1('test1');
      hook.current.mutate2('test2');
      hook.current.mutate3('test3');
    });
    // Predicate matches only ['users', 1]
    expect(hook.current.count, 1);

    await hook.rebuildWithProps(
      (key, state) => key != null && key.length > 1 && key[1] != 1,
    );
    // New predicate matches ['users', 2] and ['users', 3]
    expect(hook.current.count, 2);

    // ['users', 1] mutation completes, should not affect count
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current.count, 2);

    // ['users', 2] and ['users', 3] complete
    await tester.pump(const Duration(seconds: 1));
    expect(hook.current.count, 0);
  }));

  testWidgets(
      'SHOULD filter by key prefix '
      'WHEN exact == false', withCleanup((tester) async {
    final hook = await buildHook(() {
      final mutation1 = useMutation<String, dynamic, String, dynamic>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        mutationKey: const ['users'],
        client: client,
      );
      final mutation2 = useMutation<String, dynamic, String, dynamic>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        mutationKey: const ['users', 1],
        client: client,
      );
      final mutation3 = useMutation<String, dynamic, String, dynamic>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        mutationKey: const ['users', 2],
        client: client,
      );
      final mutation4 = useMutation<String, dynamic, String, dynamic>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        mutationKey: const ['posts', 1],
        client: client,
      );
      return (
        mutate1: mutation1.mutate,
        mutate2: mutation2.mutate,
        mutate3: mutation3.mutate,
        mutate4: mutation4.mutate,
        users: useIsMutating(
          mutationKey: const ['users'],
          exact: false,
          client: client,
        ),
        posts: useIsMutating(
          mutationKey: const ['posts'],
          exact: false,
          client: client,
        ),
        comments: useIsMutating(
          mutationKey: const ['comments'],
          exact: false,
          client: client,
        ),
      );
    });

    await act(() {
      hook.current.mutate1('test1');
      hook.current.mutate2('test2');
      hook.current.mutate3('test3');
      hook.current.mutate4('test4');
    });

    expect(hook.current.users, 3);
    expect(hook.current.posts, 1);
    expect(hook.current.comments, 0);
  }));

  testWidgets(
      'SHOULD filter by exact key '
      'WHEN exact == true', withCleanup((tester) async {
    final hook = await buildHook(() {
      final mutation1 = useMutation<String, dynamic, String, dynamic>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        mutationKey: const ['users'],
        client: client,
      );
      final mutation2 = useMutation<String, dynamic, String, dynamic>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        mutationKey: const ['users', 1],
        client: client,
      );
      final mutation3 = useMutation<String, dynamic, String, dynamic>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        mutationKey: const ['users', 2],
        client: client,
      );
      return (
        mutate1: mutation1.mutate,
        mutate2: mutation2.mutate,
        mutate3: mutation3.mutate,
        count: useIsMutating(
          mutationKey: const ['users'],
          exact: true,
          client: client,
        ),
      );
    });

    await act(() {
      hook.current.mutate1('test1');
      hook.current.mutate2('test2');
      hook.current.mutate3('test3');
    });

    expect(hook.current.count, 1);
  }));

  testWidgets(
      'SHOULD filter by predicate'
      '', withCleanup((tester) async {
    final hook = await buildHook(() {
      final mutation1 = useMutation<String, dynamic, String, dynamic>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        mutationKey: const ['users'],
        client: client,
      );
      final mutation2 = useMutation<String, dynamic, String, dynamic>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        mutationKey: const ['users', 1],
        client: client,
      );
      final mutation3 = useMutation<String, dynamic, String, dynamic>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        mutationKey: const ['users', 2],
        client: client,
      );
      return (
        mutate1: mutation1.mutate,
        mutate2: mutation2.mutate,
        mutate3: mutation3.mutate,
        count: useIsMutating(
          predicate: (key, state) =>
              key != null && key.length > 1 && key[1] == 1,
          client: client,
        ),
      );
    });

    await act(() {
      hook.current.mutate1('test1');
      hook.current.mutate2('test2');
      hook.current.mutate3('test3');
    });

    expect(hook.current.count, 1);
  }));

  testWidgets(
      'SHOULD filter by key and predicate'
      '', withCleanup((tester) async {
    final hook = await buildHook(() {
      final mutation1 = useMutation<String, dynamic, String, dynamic>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        mutationKey: const ['users', 1],
        client: client,
      );
      final mutation2 = useMutation<String, dynamic, String, dynamic>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        mutationKey: const ['users', 2],
        client: client,
      );
      final mutation3 = useMutation<String, dynamic, String, dynamic>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        mutationKey: const ['posts', 1],
        client: client,
      );
      return (
        mutate1: mutation1.mutate,
        mutate2: mutation2.mutate,
        mutate3: mutation3.mutate,
        count: useIsMutating(
          mutationKey: const ['users'],
          predicate: (key, state) =>
              key != null && key.length > 1 && key[1] == 1,
          client: client,
        ),
      );
    });

    await act(() {
      hook.current.mutate1('test1');
      hook.current.mutate2('test2');
      hook.current.mutate3('test3');
    });

    expect(hook.current.count, 1);
  }));
}
