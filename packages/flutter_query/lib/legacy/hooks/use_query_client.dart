import 'package:flutter_hooks/flutter_hooks.dart';
import '../query_client.dart';
import 'package:provider/provider.dart';

QueryClient useQueryClient() {
  final context = useContext();
  return context.watch<QueryClient>();
}
