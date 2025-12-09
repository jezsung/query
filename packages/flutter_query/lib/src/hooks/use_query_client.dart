import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:provider/provider.dart';

import 'package:flutter_query/flutter_query.dart';

QueryClient useQueryClient() {
  final context = useContext();
  return context.watch<QueryClient>();
}
