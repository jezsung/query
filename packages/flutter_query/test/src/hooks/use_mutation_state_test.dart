import 'package:flutter/widgets.dart';

import 'package:flutter_hooks/flutter_hooks.dart';
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
      'SHOULD return empty list '
      'WHEN no mutations exist', withCleanup((tester) async {
    final hook = await buildHook(
      () => useMutationState(client: client),
    );

    expect(hook.current, isEmpty);
  }));

  testWidgets(
      'SHOULD return mutation states '
      'WHEN mutations exist', withCleanup((tester) async {
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
        states: useMutationState(client: client),
      );
    });

    expect(hook.current.states, isEmpty);

    await act(() => hook.current.mutate('test'));

    expect(hook.current.states, hasLength(1));
    expect(hook.current.states.first.status, MutationStatus.pending);
    expect(hook.current.states.first.variables, 'test');
  }));

  testWidgets(
      'SHOULD return multiple mutation states '
      'WHEN multiple mutations exist', withCleanup((tester) async {
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
        states: useMutationState(client: client),
      );
    });

    expect(hook.current.states, isEmpty);

    await act(() {
      hook.current.mutate1('test-1');
      hook.current.mutate2('test-2');
    });

    expect(hook.current.states, hasLength(2));
  }));

  testWidgets(
      'SHOULD update states '
      'WHEN mutation status changes', withCleanup((tester) async {
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
        states: useMutationState(client: client),
      );
    });

    await act(() => hook.current.mutate('test'));

    expect(hook.current.states.first.status, MutationStatus.pending);

    // Mutation completes after 1 second
    await tester.pump(const Duration(seconds: 1));

    expect(hook.current.states.first.status, MutationStatus.success);
    expect(hook.current.states.first.data, 'data');
  }));

  testWidgets(
      'SHOULD filter by key prefix '
      'WHEN mutationKey provided and exact == false',
      withCleanup((tester) async {
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
        mutationKey: const ['posts', 1],
        client: client,
      );
      return (
        mutate1: mutation1.mutate,
        mutate2: mutation2.mutate,
        mutate3: mutation3.mutate,
        userStates: useMutationState(
          mutationKey: const ['users'],
          exact: false,
          client: client,
        ),
        postStates: useMutationState(
          mutationKey: const ['posts'],
          exact: false,
          client: client,
        ),
      );
    });

    await act(() {
      hook.current.mutate1('test1');
      hook.current.mutate2('test2');
      hook.current.mutate3('test3');
    });

    expect(hook.current.userStates, hasLength(2));
    expect(hook.current.postStates, hasLength(1));
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
        states: useMutationState(
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

    expect(hook.current.states, hasLength(1));
    expect(hook.current.states.first.variables, 'test1');
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
        mutationKey: const ['users', 3],
        client: client,
      );
      return (
        mutate1: mutation1.mutate,
        mutate2: mutation2.mutate,
        mutate3: mutation3.mutate,
        states: useMutationState(
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

    expect(hook.current.states, hasLength(1));
    expect(hook.current.states.first.variables, 'test1');
  }));

  testWidgets(
      'SHOULD filter by status via predicate'
      '', withCleanup((tester) async {
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
        pendingStates: useMutationState(
          predicate: (key, state) => state.status == MutationStatus.pending,
          client: client,
        ),
        successStates: useMutationState(
          predicate: (key, state) => state.status == MutationStatus.success,
          client: client,
        ),
      );
    });

    await act(() {
      hook.current.mutate1('test-1');
      hook.current.mutate2('test-2');
    });

    expect(hook.current.pendingStates, hasLength(2));
    expect(hook.current.successStates, isEmpty);

    // Second mutation completes after 1 second
    await tester.pump(const Duration(seconds: 1));

    expect(hook.current.pendingStates, hasLength(1));
    expect(hook.current.successStates, hasLength(1));

    // First mutation completes after another 1 second
    await tester.pump(const Duration(seconds: 1));

    expect(hook.current.pendingStates, isEmpty);
    expect(hook.current.successStates, hasLength(2));
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
        states: useMutationState(
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

    expect(hook.current.states, hasLength(1));
    expect(hook.current.states.first.variables, 'test1');
  }));

  testWidgets(
      'SHOULD return new states '
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
          states: useMutationState(mutationKey: mutationKey, client: client),
        );
      },
      initialProps: const ['users'],
    );

    await act(() {
      hook.current.mutate1('test1');
      hook.current.mutate2('test2');
      hook.current.mutate3('test3');
    });
    expect(hook.current.states, hasLength(2));

    await hook.rebuildWithProps(const ['posts']);
    expect(hook.current.states, hasLength(1));
  }));

  testWidgets(
      'SHOULD return new states '
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
          states: useMutationState(
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
    expect(hook.current.states, hasLength(3));

    await hook.rebuildWithProps(true);
    expect(hook.current.states, hasLength(1));
  }));

  testWidgets(
      'SHOULD return new states '
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
          states: useMutationState(predicate: predicate, client: client),
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
    expect(hook.current.states, hasLength(1));

    await hook.rebuildWithProps(
      (key, state) => key != null && key.length > 1 && key[1] != 1,
    );
    // New predicate matches ['users', 2] and ['users', 3]
    expect(hook.current.states, hasLength(2));
  }));

  testWidgets(
      'SHOULD update when mutation is added'
      '', withCleanup((tester) async {
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
        states: useMutationState(client: client),
      );
    });

    expect(hook.current.states, isEmpty);

    await act(() => hook.current.mutate('first'));
    expect(hook.current.states, hasLength(1));

    await act(() => hook.current.mutate('second'));
    expect(hook.current.states, hasLength(2));
  }));

  testWidgets(
      'SHOULD update when mutation is removed'
      '', withCleanup((tester) async {
    late MutationResult<String, dynamic, String, dynamic> result;
    late List<MutationState> states;

    await tester.pumpWidget(Column(children: [
      HookBuilder(
        key: Key('result'),
        builder: (context) {
          result = useMutation<String, dynamic, String, dynamic>(
            (variables, context) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'data';
            },
            gcDuration: const GcDuration(minutes: 3),
            client: client,
          );
          return const SizedBox();
        },
      ),
      HookBuilder(
        key: Key('states'),
        builder: (context) {
          states = useMutationState(client: client);
          return const SizedBox();
        },
      ),
    ]));

    expect(states, isEmpty);

    await act(() => result.mutate('test'));
    expect(states, hasLength(1));

    // Mutation completes after 1 second
    await tester.pump(const Duration(seconds: 1));
    expect(states, hasLength(1));

    // Mutation is garbage collected after another 3 minutes
    await tester.pumpWidget(Column(children: [
      HookBuilder(
        key: Key('states'),
        builder: (context) {
          states = useMutationState(client: client);
          return const SizedBox();
        },
      ),
    ]));
    await tester.pump(const Duration(minutes: 3));
    expect(states, isEmpty);
  }));
}
