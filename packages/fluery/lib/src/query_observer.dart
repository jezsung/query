import 'package:fluery/src/query.dart';

class QueryObserver<Data> {
  QueryObserver({
    required this.query,
    required this.fetcher,
    required this.staleDuration,
  });

  final Query query;
  final QueryFetcher<Data> fetcher;
  final Duration staleDuration;

  Future<void> fetch() async {
    await query.fetch(
      fetcher: fetcher,
      staleDuration: staleDuration,
    );
  }
}
