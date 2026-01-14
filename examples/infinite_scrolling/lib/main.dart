import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'api.dart';

void main() {
  final queryClient = QueryClient();
  runApp(QueryClientProvider(client: queryClient, child: const MainApp()));
  queryClient.dispose();
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: PostsPage());
  }
}

class PostsPage extends HookWidget {
  const PostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final result = useInfiniteQuery<List<Post>, Exception, int>(
      const ['posts'],
      (context) => fetchPosts(page: context.pageParam, limit: 10),
      initialPageParam: 0,
      nextPageParamBuilder: (data) {
        if (data.pages.last.length < 10) return null;
        return data.pageParams.last + 1;
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Posts')),
      body: PagedListView<int, Post>.separated(
        state: PagingState<int, Post>(
          pages: result.pages,
          keys: result.pageParams,
          hasNextPage: result.hasNextPage,
          isLoading: result.isFetchingNextPage,
          error: result.error,
        ),
        fetchNextPage: () {
          if (result.isFetchingNextPage) return;
          result.fetchNextPage();
        },
        separatorBuilder: (context, index) => const Divider(height: 1),
        builderDelegate: PagedChildBuilderDelegate(
          itemBuilder: (context, post, index) {
            return ListTile(
              leading: Text('${post.id}'),
              title: Text(post.title),
            );
          },
        ),
      ),
    );
  }
}
