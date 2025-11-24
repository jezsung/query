import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:query_core/query_core.dart';
import 'package:query_core/src/mutation_types.dart';
import 'package:query_core/src/query_client.dart';

MutationResult<T, P> useMutation<T, P>(Future<T> Function(P) mutationFn,
    {void Function(T)? onSuccess, void Function(Object)? onError, bool spreadCallBackLocalyOnly = false}) {
  final state = useState<MutationState<T>>(MutationState<T>(null, MutationStatus.idle, null));
  var isMounted = true;

  useEffect(() {
    state.value = MutationState<T>(null, MutationStatus.idle, null);
    return () {
      isMounted = false;
    };
  }, []);

  void mutate(P params) async {
    if (!isMounted) return;
    state.value = MutationState<T>(null, MutationStatus.pending, null);
    try {
      final data = await mutationFn(params);
      if (!isMounted) return;
      state.value = MutationState<T>(data, MutationStatus.success, null);
      onSuccess?.call(data);
      if (!spreadCallBackLocalyOnly) QueryClient.instance.mutationCache?.config.onSuccess?.call(data);
    } catch (e) {
      if (!isMounted) return;
      state.value = MutationState<T>(null, MutationStatus.error, e);
      onError?.call(e);
      if (!spreadCallBackLocalyOnly) QueryClient.instance.mutationCache?.config.onError?.call(e);
    }
  }

  return MutationResult<T, P>(mutate, state.value.data, state.value.status, state.value.error);
}
