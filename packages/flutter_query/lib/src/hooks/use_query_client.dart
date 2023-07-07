import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:provider/provider.dart';

QueryClient useQueryClient() {
  final context = useContext();
  return context.watch<QueryClient>();
}
