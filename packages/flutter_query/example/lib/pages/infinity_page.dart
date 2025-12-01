import 'package:example/conf/api_conf.dart';
import 'package:example/models/pagination.dart';
import 'package:example/widgets/todo_card.dart';
import 'package:example/widgets/floating_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:example/models/todo.dart';
import 'package:flutter_query/flutter_query.dart';

class InfinityPage extends HookWidget {
  const InfinityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final page = useState<Pagination>(Pagination(number: 1, size: 5));
    final scrollController = useScrollController();

    final infiniteTodos = useInfiniteQuery<PaginatedTodos>(
      queryKey: ["Infinite", GetAllTodosApi.name, page.value.size],
      queryFn: (int pageParam) => GetAllTodosApi.request(Pagination(number: pageParam, size: page.value.size)),
      initialPageParam: page.value.number,
      getNextPageParam: (last) => (last.page < last.totalPages) ? last.page + 1 : 0,
    );

    scrollController.addListener(() {
      if (!scrollController.hasClients) return;

      if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
        if (infiniteTodos.fetchNextPage != null) {
          infiniteTodos.fetchNextPage!();
        }
      }
    });

    if (scrollController.hasClients &&
        scrollController.position.maxScrollExtent == scrollController.position.minScrollExtent &&
        infiniteTodos.data != null &&
        infiniteTodos.data!.isNotEmpty &&
        infiniteTodos.fetchNextPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        infiniteTodos.fetchNextPage!();
      });
    }

    Widget? content;
    // initial loading
    if (infiniteTodos.isPending) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading todos...', style: TextStyle(fontSize: 16)),
        ],
      );
    }
    // error
    else if (infiniteTodos.isError || infiniteTodos.status == QueryStatus.error) {
      final err = infiniteTodos.error;
      content = Center(child: Text('Error: ${err ?? 'unknown'}'));
    }

    final items = infiniteTodos.data?.expand((p) => p.items).toList() ?? <Todo>[];

    return Stack(children: [
      Column(children: [
        // title
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Infinite List', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              "Displayed pages: ${infiniteTodos.data?.isNotEmpty == true ? infiniteTodos.data!.last.page : 1}",
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
        Expanded(
            child: ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: items.length + (infiniteTodos.isFetchingNextPage ? 1 : 0),
          itemBuilder: (context, index) {
            // render loader at the end while next page is loading
            if (index >= items.length) {
              if (infiniteTodos.isFetching) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              } else {
                return const SizedBox.shrink();
              }
            }

            final todo = items[index];
            return TodoCard(todo: todo);
          },
        )),
        // content area
        if (content != null) Expanded(child: content),
      ]),
      Positioned(right: 16, bottom: 16, child: FloatingButton()),
    ]);
  }
}
