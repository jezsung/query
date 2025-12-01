import 'package:example/conf/api_conf.dart';
import 'package:example/models/pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:example/widgets/todo_card.dart';
import 'package:example/widgets/floating_button.dart';
import 'package:flutter_query/flutter_query.dart';

class TodosPage extends HookWidget {
  const TodosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final page = useState<Pagination>(Pagination(number: 1, size: 5));

    final getAllTodosQuery = useQuery(
      queryKey: ["Classical", GetAllTodosApi.name, page.value.toJson()],
      queryFn: () => GetAllTodosApi.request(page.value),
      staleTime: 0,
    );

    Widget content = const SizedBox.shrink();

    //Is Fetching
    if (getAllTodosQuery.isFetching) {
      content = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading todos...', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    //Is Error
    else if (getAllTodosQuery.isError || getAllTodosQuery.status == QueryStatus.error) {
      final err = getAllTodosQuery.error;
      content = Center(child: Text('Error: ${err ?? 'unknown'}'));
    }

    //Is Success
    else if (getAllTodosQuery.isSuccess) {
      final paginated = getAllTodosQuery.data;
      final items = paginated?.items ?? const [];

      // No items
      if (getAllTodosQuery.isSuccess && items.isEmpty) {
        content = const Center(child: Text('No todos available.'));
      }
      // Show list of items
      else {
        content = ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final todo = items[i];
            return TodoCard(
              todo: todo,
            );
          },
        );
      }
    }

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Todo List', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          _getLabelInfo(context, getAllTodosQuery.data?.totalCount ?? 0, page.value),
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  // page controls are still available for demo
                  IconButton(
                    onPressed: () {
                      if (getAllTodosQuery.isFetching) return;

                      page.value = Pagination(
                          number: (page.value.number - 1).clamp(1, getAllTodosQuery.data?.totalPages ?? 2),
                          size: page.value.size);
                    },
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous page',
                  ),
                  Text(page.value.number.toString()),
                  IconButton(
                    onPressed: () {
                      if (getAllTodosQuery.isFetching) return;

                      page.value = Pagination(
                          number: (page.value.number + 1).clamp(1, getAllTodosQuery.data?.totalPages ?? 2),
                          size: page.value.size);
                    },
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next page',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Content area
              Expanded(child: content),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingButton(),
        ),
      ],
    );
  }
}

String _getLabelInfo(BuildContext context, int totalRows, Pagination pagination) {
  if (pagination.size > 0 && totalRows > 0) {
    final lastPossibleIndexInPage = pagination.number * pagination.size;
    final firstItemIndexInPage = lastPossibleIndexInPage - pagination.size + 1;
    final lastItemIndexInPage = lastPossibleIndexInPage.clamp(1, totalRows);

    // Hard-coded label (no localization keys)
    return "Displaying elements from $firstItemIndexInPage to $lastItemIndexInPage of $totalRows";
  } else {
    return "Displaying all $totalRows items";
  }
}
